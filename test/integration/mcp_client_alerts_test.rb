require "test_helper"
require "hitch/mcp/test_helper"

class McpClientAlertsTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper
  include ActionMailer::TestHelper

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
  end

  teardown do
    McpQuota.store_override = nil
  end

  test "the first tool call from a new client alerts the owner once" do
    assert_enqueued_emails 1 do
      call_tool("get_mail_account", account_id: mail_accounts(:work).id)
    end

    assert_no_enqueued_emails do
      call_tool("get_mail_account", account_id: mail_accounts(:work).id)
    end

    assert_equal [ [ mail_accounts(:work).id, "hitch-test-client" ] ],
      McpClientSighting.pluck(:mail_account_id, :client_id)
  end

  test "a call that names no mailbox records no sighting" do
    assert_no_enqueued_emails do
      call_tool("list_mail_accounts")
    end

    assert_equal 0, McpClientSighting.count
  end

  test "a call refused for someone else's mailbox records no sighting" do
    assert_no_enqueued_emails do
      post_mcp(method: "tools/call", token: @token,
        params: { name: "get_mail_account", arguments: { account_id: mail_accounts(:personal).id } })
    end

    assert_equal 0, McpClientSighting.count
  end

  private
    def call_tool(name, **arguments)
      post_mcp(method: "tools/call", token: @token, params: { name:, arguments: })

      assert_response :success
      assert_not response.parsed_body.dig("result", "isError"), response.body
    end
end
