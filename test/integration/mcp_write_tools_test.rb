require "test_helper"
require "hitch/mcp/test_helper"

# Write tools against the real /mcp endpoint, with a registry holding one throwaway write tool:
# no real write tool ships yet, and the gate must hold before the first one does.
class McpWriteToolsTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  class TouchMailbox < McpTools::ApplicationTool
    tool_name "touch_mailbox"
    title "Touch mailbox"
    description "Test-only write tool."
    write_tool destructive: false
    input_schema(
      type: "object",
      properties: { account_id: { type: "integer" } },
      required: [ "account_id" ],
      additionalProperties: false
    )

    private
      def call
        rows_returned!(1)
        Hitch::MCP::Result.text("touched #{mail_account.id}")
      end
  end

  class Registry < McpToolRegistry
    register TouchMailbox, scopes: [ "mcp" ]
  end

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @registry = Hitch.configuration.mcp.registry
    Hitch.configuration.mcp.registry = Registry.name
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
  end

  teardown do
    Hitch.configuration.mcp.registry = @registry
    McpQuota.store_override = nil
  end

  test "a write tool is listed as not read-only" do
    post_mcp(method: "tools/list", token: @token)

    tool = response.parsed_body.dig("result", "tools").sole
    assert_equal [ "touch_mailbox", false, false ],
      [ tool["name"], tool.dig("annotations", "readOnlyHint"), tool.dig("annotations", "destructiveHint") ]
  end

  test "a write tool on a read-only mailbox is refused with what the owner has to do, and audited" do
    account = mail_accounts(:work)
    result = call_tool("touch_mailbox", account_id: account.id)

    assert result["isError"]
    assert_equal McpTools::ApplicationTool::READ_ONLY_MAILBOX, result.dig("content", 0, "text")
    assert_equal [ @user.id, "touch_mailbox", "denied", account.id, 0 ],
      McpAuditEvent.sole.values_at(:user_id, :tool_name, :outcome, :mail_account_id, :rows_returned)
  end

  test "a write tool runs on a mailbox whose owner allowed changes" do
    account = mail_accounts(:work)
    account.update!(writable: true)

    result = call_tool("touch_mailbox", account_id: account.id)

    assert_not result["isError"], result.to_json
    assert_equal "touched #{account.id}", result.dig("content", 0, "text")
    assert_equal [ "ok", account.id, 1 ], McpAuditEvent.sole.values_at(:outcome, :mail_account_id, :rows_returned)
  end

  test "another user's writable mailbox is still refused as foreign" do
    other = mail_accounts(:personal)
    other.update!(writable: true)

    result = call_tool("touch_mailbox", account_id: other.id)

    assert result["isError"]
    assert_equal [ "denied", other.id ], McpAuditEvent.sole.values_at(:outcome, :mail_account_id)
  end

  private
    def call_tool(name, **arguments)
      post_mcp(method: "tools/call", token: @token, params: { name:, arguments: })

      assert_response :success
      response.parsed_body.fetch("result")
    end
end
