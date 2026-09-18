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
    assert_equal %w[get_mail_account list_mail_accounts search_messages], tools.map { |tool| tool["name"] }
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

  test "search_messages answers with compact header rows and nothing resembling a body" do
    message = index_message(mail_accounts(:work), uid: 1, subject: "Faktura za září", from_name: "Žlutý Kůň",
      from_address: "billing@example.com",
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 12_345 } ])
    index_message(mail_accounts(:work), uid: 2, subject: "Lunch")

    payload = search(query: "FAKTURA zari")

    assert_equal [ 1, false ], payload.values_at("returned", "truncated")
    row = payload["messages"].sole
    assert_equal %w[account_id attachments date folder from has_attachments id subject], row.keys.sort
    assert_equal [ message.id, mail_accounts(:work).id, "INBOX", "Žlutý Kůň <billing@example.com>", true ],
      row.values_at("id", "account_id", "folder", "from", "has_attachments")
    assert_equal [ { "filename" => "faktura.pdf", "size" => 12_345 } ], row["attachments"]
    assert_equal [ "search_messages", "ok", 1 ], McpAuditEvent.sole.values_at(:tool_name, :outcome, :rows_returned)
  end

  test "search_messages never reaches another user's mail" do
    index_message(mail_accounts(:personal), uid: 1, subject: "Faktura pro někoho jiného")

    assert_empty search(query: "faktura")["messages"]
    assert_equal [ "ok", 0 ], McpAuditEvent.sole.values_at(:outcome, :rows_returned)
  end

  test "search_messages refuses an account_id belonging to someone else" do
    index_message(mail_accounts(:personal), uid: 1, subject: "Faktura")

    result = call_tool("search_messages", query: "faktura", account_id: mail_accounts(:personal).id)

    assert result["isError"]
    assert_not_includes result.to_json, "Faktura"
    assert_equal [ "denied", 0 ], McpAuditEvent.sole.values_at(:outcome, :rows_returned)
  end

  test "search_messages caps the rows, says there are more and audits what it handed over" do
    5.times { |i| index_message(mail_accounts(:work), uid: i + 1, subject: "Faktura #{i}") }

    payload = search(query: "faktura", limit: 2)

    assert_equal [ 2, true ], payload.values_at("returned", "truncated")
    assert_includes payload["note"], "Narrow"
    assert_equal 2, McpAuditEvent.sole.rows_returned
  end

  test "search_messages refuses to hand out more rows than the page cap, however large the limit" do
    (McpSearchGuard::MAX_PAGE_SIZE + 1).times { |i| index_message(mail_accounts(:work), uid: i + 1, subject: "Faktura #{i}") }

    assert_equal McpSearchGuard::MAX_PAGE_SIZE, search(query: "faktura", limit: 10_000)["returned"]
  end

  test "search_messages narrows by account, folder and date range, newest first" do
    account = mail_accounts(:work)
    second = users(:one).mail_accounts.create!(host: "imap.example.org", username: "one", password: "x")
    january = index_message(account, uid: 1, subject: "Faktura leden", date: Time.zone.parse("2026-01-05 09:00"))
    september = index_message(account, uid: 2, subject: "Faktura září", date: Time.zone.parse("2026-09-05 09:00"))
    archived = index_message(account, uid: 3, subject: "Faktura archiv", folder: "Archive")
    elsewhere = index_message(second, uid: 1, subject: "Faktura jinde")

    assert_equal [ september.id, january.id ],
      search(query: "faktura", folder: "inbox", account_id: account.id)["messages"].map { |row| row["id"] }
    assert_equal [ september.id ],
      search(query: "faktura", since: "2026-09-05", until: "2026-09-05")["messages"].map { |row| row["id"] }
    assert_equal [ elsewhere.id ], search(query: "faktura", account_id: second.id)["messages"].map { |row| row["id"] }
    assert_includes search(query: "faktura")["messages"].map { |row| row["id"] }, archived.id
  end

  test "search_messages explains a date it cannot read instead of ignoring it" do
    result = call_tool("search_messages", query: "faktura", since: "not-a-date")

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "YYYY-MM-DD"
  end

  test "search_messages asks for something to search for" do
    result = call_tool("search_messages", query: "   ")

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "something to look for"
  end

  test "the search row budget stops a walk through the whole mailbox and is audited" do
    index_message(mail_accounts(:work), uid: 1, subject: "Faktura")
    McpSearchGuard::ROWS.consume(@user, McpSearchGuard::ROWS.to)

    result = call_tool("search_messages", query: "faktura")

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "row budget"
    assert_equal [ "search_limited", 0 ], McpAuditEvent.sole.values_at(:outcome, :rows_returned)
  end

  private
    def search(**arguments)
      result = call_tool("search_messages", **arguments)

      assert_not result["isError"], result.to_json
      JSON.parse(result.dig("content", 0, "text"))
    end

    def index_message(account, uid:, subject:, folder: "INBOX", date: Time.current, from_name: nil,
      from_address: "sender@example.com", attachments: [])
      mail_folder = account.mail_folders.find_or_create_by!(name: folder) { |new_folder| new_folder.uidvalidity = 1 }
      account.mail_messages.create!(
        mail_folder:, uidvalidity: mail_folder.uidvalidity, uid:, subject:, date:, from_name:, from_address:,
        has_attachments: attachments.any?, attachments:,
        search_text: MailMessage.build_search_text(
          subject:, from_name:, from_address:, to_addresses: [], cc_addresses: []
        )
      )
    end

    def call_tool(name, token: @token, **arguments)
      post_mcp(method: "tools/call", token:, params: { name:, arguments: })

      assert_response :success
      response.parsed_body.fetch("result")
    end
end
