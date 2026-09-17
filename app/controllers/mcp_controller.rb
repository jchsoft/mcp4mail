# frozen_string_literal: true

# Authenticated MCP endpoint (hitch-rails): bearer-token auth, host/origin
# admission and rate limiting come from Hitch; tools from McpToolRegistry.
class McpController < ActionController::API
  include Hitch::MCP::Endpoint
end
