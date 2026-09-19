require "test_helper"
require "hitch/mcp/test_helper"

class McpLegacyHandshakeTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  setup do
    host! URI(Hitch.configuration.resource_uri).then { |uri| "#{uri.host}:#{uri.port}" }
    @token = mint_mcp_token(principal: users(:one))
  end

  test "legacy initialize handshake echoes a known requested version" do
    post_legacy(
      {
        "jsonrpc" => "2.0",
        "id" => "init-1",
        "method" => "initialize",
        "params" => { "protocolVersion" => "2025-11-25", "capabilities" => {} }
      }
    )

    assert_response :success
    result = response.parsed_body["result"]
    assert_equal "2025-11-25", result["protocolVersion"]
    assert_equal false, result.dig("capabilities", "tools", "listChanged")
    assert_equal "mcp4mail", result.dig("serverInfo", "name")
    assert response.headers["Mcp-Session-Id"].present?
    assert_includes response.headers["Access-Control-Expose-Headers"], "Mcp-Session-Id"
  end

  test "legacy initialize handshake falls back to the default version when unknown" do
    post_legacy(
      {
        "jsonrpc" => "2.0",
        "id" => "init-2",
        "method" => "initialize",
        "params" => { "protocolVersion" => "1999-01-01", "capabilities" => {} }
      }
    )

    assert_response :success
    assert_equal "2025-06-18", response.parsed_body.dig("result", "protocolVersion")
  end

  test "notifications are accepted without a body" do
    post_legacy({ "jsonrpc" => "2.0", "method" => "notifications/initialized", "params" => {} })

    assert_response :accepted
  end

  test "ping answers an empty result" do
    post_legacy({ "jsonrpc" => "2.0", "id" => "ping-1", "method" => "ping" })

    assert_response :success
    assert_equal "ping-1", response.parsed_body["id"]
    assert_equal({}, response.parsed_body["result"])
  end

  test "legacy tools/list without _meta is rewritten and dispatched" do
    post_legacy(
      { "jsonrpc" => "2.0", "id" => "list-1", "method" => "tools/list", "params" => {} },
      accept: "application/json"
    )

    assert_response :success
    assert_includes response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }, "list_mail_accounts"
  end

  test "legacy tools/call without _meta reaches the real dispatch layer" do
    post_legacy(
      { "jsonrpc" => "2.0", "id" => "call-1", "method" => "tools/call", "params" => { "name" => "does_not_exist" } },
      accept: "application/json"
    )

    assert_response :success
    assert_equal "call-1", response.parsed_body["id"]
    assert response.parsed_body.key?("error"), "expected a dispatched JSON-RPC error, not a header mismatch"
  end

  test "a genuine 2026-07-28 tools/list request passes through untouched" do
    response = post_mcp(method: "tools/list", token: @token)

    assert_response :success
    assert_includes response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }, "list_mail_accounts"
  end

  private
    def post_legacy(body, accept: "application/json, text/event-stream")
      post "/mcp",
        params: JSON.generate(body),
        headers: {
          "Content-Type" => "application/json",
          "Accept" => accept,
          "Authorization" => "Bearer #{@token}"
        }
    end
end
