require "test_helper"
require "hitch/mcp/test_helper"

class McpToolsTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
  end

  teardown do
    McpQuota.store_override = nil
  end

  test "every listed tool declares itself read-only and non-destructive" do
    post_mcp(method: "tools/list", token: @token)

    assert_response :success
    tools = response.parsed_body.dig("result", "tools")
    assert_equal %w[get_mail_account list_mail_accounts], tools.map { |tool| tool["name"] }
    tools.each do |tool|
      assert_equal true, tool.dig("annotations", "readOnlyHint"), tool["name"]
      assert_equal false, tool.dig("annotations", "destructiveHint"), tool["name"]
    end
  end

  test "list_mail_accounts returns only the caller's accounts and audits the row count" do
    result = call_tool("list_mail_accounts")

    accounts = JSON.parse(result.dig("content", 0, "text"))
    assert_equal [ mail_accounts(:work).id ], accounts.map { |account| account["id"] }
    assert_not_includes result.to_json, "fixture-app-password"

    event = McpAuditEvent.sole
    assert_equal [ @user, "list_mail_accounts", "ok", 1, "hitch-test-client" ],
      [ event.user, event.tool_name, event.outcome, event.rows_returned, event.client_id ]
    assert_nil event.mail_account_id
  end

  test "get_mail_account answers for the caller's own account" do
    result = call_tool("get_mail_account", account_id: mail_accounts(:work).id)

    assert_not result["isError"]
    assert_equal "imap.example.com", JSON.parse(result.dig("content", 0, "text"))["host"]
    assert_equal [ "ok", mail_accounts(:work).id, 1 ], McpAuditEvent.sole.values_at(:outcome, :mail_account_id, :rows_returned)
  end

  test "an account id belonging to another user is refused, leaks nothing and is audited" do
    other = mail_accounts(:personal)
    result = call_tool("get_mail_account", account_id: other.id)

    assert result["isError"]
    assert_not_includes result.to_json, other.host
    assert_not_includes result.to_json, other.username
    assert_equal [ @user.id, "denied", other.id, 0 ], McpAuditEvent.sole.values_at(:user_id, :outcome, :mail_account_id, :rows_returned)
  end

  test "an account id that does not exist is refused the same way" do
    result = call_tool("get_mail_account", account_id: MailAccount.maximum(:id) + 1)

    assert result["isError"]
    assert_equal "denied", McpAuditEvent.sole.outcome
  end

  test "the per-user quota refuses calls across all clients once used up" do
    McpTools::ApplicationTool::USER_CALLS.consume(@user, McpTools::ApplicationTool::USER_CALLS.to)
    other_client_token = mint_mcp_token(principal: @user, client_id: "another-client")

    result = call_tool("list_mail_accounts", token: other_client_token)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "Rate limit exceeded"
    event = McpAuditEvent.sole
    assert_equal [ "rate_limited", 0, "another-client" ], event.values_at(:outcome, :rows_returned, :client_id)
  end

  test "the per-user quota does not spill over to another user" do
    McpTools::ApplicationTool::USER_CALLS.consume(users(:two), McpTools::ApplicationTool::USER_CALLS.to)

    assert_not call_tool("list_mail_accounts")["isError"]
  end

  private
    def call_tool(name, token: @token, **arguments)
      post_mcp(method: "tools/call", token:, params: { name:, arguments: })

      assert_response :success
      response.parsed_body.fetch("result")
    end
end
