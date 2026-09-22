require "test_helper"
require "hitch/mcp/test_helper"

class McpSendMessageTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper
  include ActionMailer::TestHelper

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
    @account = mail_accounts(:work)
    @account.update!(writable: true)
  end

  teardown do
    McpQuota.store_override = nil
  end

  test "send_message is listed as a destructive write tool" do
    post_mcp(method: "tools/list", token: @token)

    tool = response.parsed_body.dig("result", "tools").find { |listed| listed["name"] == "send_message" }
    assert_equal [ false, true ], [ tool.dig("annotations", "readOnlyHint"), tool.dig("annotations", "destructiveHint") ]
  end

  test "send_message stores the message, emails the owner and sends nothing" do
    result = call_tool("send_message", account_id: @account.id, to: "bob@example.org, carol@example.org",
      subject: "Lunch", body: "Friday?")

    assert_includes enqueued_jobs.map { |job| job["arguments"].first }, "OutgoingMessagesMailer"

    assert_not result["isError"], result.to_json
    payload = JSON.parse(result.dig("content", 0, "text"))
    outgoing = OutgoingMessage.find(payload["outgoing_message_id"])
    assert_equal "pending", payload["state"]
    assert_equal McpTools::SendMessage::WAITING, payload["message"]
    assert_equal [ %w[bob@example.org carol@example.org], "Lunch", "Friday?", @user ],
      [ outgoing.to_addresses, outgoing.subject, outgoing.body, outgoing.user ]
    assert_equal [ "send_message", "ok" ], McpAuditEvent.sole.values_at(:tool_name, :outcome)
  end

  test "send_message is refused on a read-only mailbox" do
    @account.update!(writable: false)

    result = call_tool("send_message", account_id: @account.id, to: "bob@example.org", body: "Hi")

    assert result["isError"]
    assert_equal McpTools::ApplicationTool::READ_ONLY_MAILBOX, result.dig("content", 0, "text")
    assert_equal 0, OutgoingMessage.count
    assert_equal "denied", McpAuditEvent.sole.outcome
  end

  test "send_message refuses more than 20 recipients" do
    recipients = Array.new(21) { |index| "person#{index}@example.org" }

    result = call_tool("send_message", account_id: @account.id, to: recipients, body: "Hi")

    assert result["isError"]
    assert_match "at most 20 recipients", result.dig("content", 0, "text")
    assert_equal 0, OutgoingMessage.count
  end

  test "send_message refuses an eleventh message waiting in the mailbox" do
    10.times { call_tool("send_message", account_id: @account.id, to: "bob@example.org", body: "Hi") }

    result = call_tool("send_message", account_id: @account.id, to: "bob@example.org", body: "Hi")

    assert result["isError"]
    assert_match "already waiting for approval", result.dig("content", 0, "text")
    assert_equal 10, OutgoingMessage.count
  end

  test "send_message needs a recipient" do
    result = call_tool("send_message", account_id: @account.id, body: "Hi")

    assert result["isError"]
    assert_match "at least one recipient", result.dig("content", 0, "text")
  end

  test "get_outgoing_status reports the state, and expiry" do
    payload = JSON.parse(call_tool("send_message", account_id: @account.id, to: "bob@example.org", body: "Hi").dig("content", 0, "text"))
    id = payload["outgoing_message_id"]

    status = JSON.parse(call_tool("get_outgoing_status", outgoing_message_id: id).dig("content", 0, "text"))
    assert_equal [ "pending", nil, @account.id ], status.values_at("state", "sent_at", "account_id")

    OutgoingMessage.find(id).update!(expires_at: 1.minute.ago)
    status = JSON.parse(call_tool("get_outgoing_status", outgoing_message_id: id).dig("content", 0, "text"))
    assert_equal "expired", status["state"]
  end

  test "get_outgoing_status does not see another user's messages" do
    other = mail_accounts(:personal)
    composer = MessageComposer.new(other, to: [ "bob@example.org" ], body: "Hi")
    outgoing = OutgoingMessage.prepare!(mail_account: other, client_id: "claude", composer:)

    result = call_tool("get_outgoing_status", outgoing_message_id: outgoing.id)

    assert result["isError"]
    assert_equal "No outgoing message with that id.", result.dig("content", 0, "text")
  end

  private
    def call_tool(name, **arguments)
      post_mcp(method: "tools/call", token: @token, params: { name:, arguments: })

      assert_response :success
      response.parsed_body.fetch("result")
    end
end
