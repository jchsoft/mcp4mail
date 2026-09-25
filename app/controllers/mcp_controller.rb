# frozen_string_literal: true

require "json"

# Authenticated MCP endpoint (hitch-rails): bearer-token auth, host/origin
# admission and rate limiting come from Hitch; tools from McpToolRegistry.
#
# hitch-rails 0.5.0 speaks only the stateless MCP 2026-07-28 profile. Claude.ai,
# ChatGPT and Grok still open with the stateful `initialize` handshake, so
# without translating it locally they connect and see no tools at all
# (mcptask.online bug #12565 — the fix below is proven in zuboklik-web).
#
# Delete this layer, not maintain it, once hitch-rails gains native legacy
# support.
class McpController < ActionController::API
  include Hitch::MCP::Endpoint

  LEGACY_VERSIONS = %w[2025-03-26 2025-06-18 2025-11-25].freeze
  DEFAULT_LEGACY_VERSION = "2025-06-18"

  before_action :translate_legacy_handshake!, only: :handle

  private
    def translate_legacy_handshake!
      legacy_request = parsed_legacy_request
      return unless legacy_request

      case legacy_request["method"]
      when "initialize" then render_initialize_result(legacy_request)
      when %r{\Anotifications/} then head :accepted
      when "ping" then render_ping_result(legacy_request)
      when "tools/list", "tools/call" then rewrite_legacy_tool_request!(legacy_request)
      end
    end

    def parsed_legacy_request
      raw_body = hitch_read_bounded_request_body(Hitch.configuration.mcp.max_request_bytes)
      return unless raw_body

      JSON.parse(raw_body)
    rescue JSON::ParserError
      nil
    end

    def render_initialize_result(legacy_request)
      requested_version = legacy_request.dig("params", "protocolVersion")
      echoed_version = LEGACY_VERSIONS.include?(requested_version) ? requested_version : DEFAULT_LEGACY_VERSION

      response.headers["Mcp-Session-Id"] = SecureRandom.uuid
      response.headers["Access-Control-Expose-Headers"] = "Mcp-Session-Id"

      # MCP puts `instructions` beside `serverInfo`, not inside it.
      server_info = Hitch.configuration.mcp.server_info.stringify_keys
      instructions = server_info.delete("instructions")

      render json: {
        jsonrpc: "2.0",
        id: legacy_request["id"],
        result: {
          protocolVersion: echoed_version,
          capabilities: { tools: { listChanged: false } },
          serverInfo: server_info,
          instructions: instructions
        }.compact
      }
    end

    def render_ping_result(legacy_request)
      render json: { jsonrpc: "2.0", id: legacy_request["id"], result: {} }
    end

    # Genuine 2026-07-28 calls already carry the protocol version in `_meta`
    # and pass through untouched; only requests missing it are legacy.
    def rewrite_legacy_tool_request!(legacy_request)
      existing_meta = legacy_request.dig("params", "_meta")
      return if existing_meta.is_a?(Hash) && existing_meta["io.modelcontextprotocol/protocolVersion"].is_a?(String)

      params_hash = (legacy_request["params"] ||= {})
      progress_token = params_hash.dig("_meta", "progressToken")
      params_hash["_meta"] = {
        "io.modelcontextprotocol/protocolVersion" => Hitch::MCP::Protocol::VERSION,
        "io.modelcontextprotocol/clientCapabilities" => {}
      }.tap { |meta| meta["progressToken"] = progress_token if progress_token }

      request.set_header("RAW_POST_DATA", JSON.generate(legacy_request))
      request.set_header("HTTP_MCP_PROTOCOL_VERSION", Hitch::MCP::Protocol::VERSION)
      request.set_header("HTTP_MCP_METHOD", legacy_request["method"])
      request.set_header("HTTP_MCP_NAME", params_hash["name"]) if legacy_request["method"] == "tools/call"
      request.set_header("HTTP_ACCEPT", "application/json, text/event-stream")
    end
end
