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

  test "every listed tool but the write tools declares itself read-only and non-destructive" do
    post_mcp(method: "tools/list", token: @token)

    assert_response :success
    listed = response.parsed_body.dig("result", "tools")
    assert_equal %w[create_draft create_folder get_attachment get_mail_account get_message get_outgoing_status list_folders list_mail_accounts move_message search_contacts search_messages send_message set_flags trash_message],
      listed.map { |tool| tool["name"] }
    tools = listed.reject { |tool| %w[create_draft create_folder move_message send_message set_flags trash_message].include?(tool["name"]) }
    tools.each do |tool|
      assert_equal true, tool.dig("annotations", "readOnlyHint"), tool["name"]
      assert_equal false, tool.dig("annotations", "destructiveHint"), tool["name"]
      assert_equal true, tool.dig("annotations", "idempotentHint"), tool["name"]
      assert_equal false, tool.dig("annotations", "openWorldHint"), tool["name"]
    end
  end

  test "every listed tool carries its human title" do
    post_mcp(method: "tools/list", token: @token)

    titles = response.parsed_body.dig("result", "tools").to_h { |tool| [ tool["name"], tool.dig("annotations", "title") ] }
    assert_equal({
      "create_draft" => "Save a draft",
      "create_folder" => "Create folder",
      "list_folders" => "List folders",
      "move_message" => "Move message",
      "get_attachment" => "Download attachment",
      "get_mail_account" => "Show mailbox",
      "get_message" => "Read message",
      "get_outgoing_status" => "Check a sent email",
      "list_mail_accounts" => "List mailboxes",
      "search_contacts" => "Search contacts",
      "search_messages" => "Search messages",
      "send_message" => "Send email (after approval)",
      "set_flags" => "Flag or mark read",
      "trash_message" => "Move to Trash"
    }, titles)
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

  test "search_contacts finds a person by exact name, partial name and address fragment" do
    index_contact_message(uid: 1, from_name: "Marie Novák", from_address: "marie@example.com",
      date: Time.zone.parse("2026-09-01 10:00"))
    index_contact_message(uid: 2, from_name: "Marie Novák", from_address: "marie@example.com",
      date: Time.zone.parse("2026-09-10 10:00"))
    index_contact_message(uid: 3, from_name: "Petr Svoboda", from_address: "petr@example.org")

    exact = contacts(query: "Marie Novák")
    assert_equal [ [ "Marie Novák", "marie@example.com", 2, "from" ] ],
      exact.map { |c| c.values_at("name", "address", "messages_count", "direction") }
    assert_equal Time.zone.parse("2026-09-10 10:00"), Time.zone.parse(exact.sole["last_seen_at"])
    assert_equal [ "marie@example.com" ], contacts(query: "mari").map { |c| c["address"] }
    assert_equal [ "petr@example.org" ], contacts(query: "example.org").map { |c| c["address"] }
    assert_equal [ "search_contacts", "ok", 1 ], McpAuditEvent.last.values_at(:tool_name, :outcome, :rows_returned)
  end

  test "search_contacts ignores accents and case, in both directions" do
    index_contact_message(uid: 1, from_name: "Marie Novák", from_address: "marie@example.com")

    assert_equal [ "marie@example.com" ], contacts(query: "NOVAK").map { |c| c["address"] }
    index_contact_message(uid: 2, from_name: "Zdeněk", from_address: "z@example.com")
    assert_equal [ "z@example.com" ], contacts(query: "Zdenek").map { |c| c["address"] }
  end

  test "search_contacts merges recipients, reports direction and orders by message count" do
    index_contact_message(uid: 1, from_name: "Me", from_address: "one@example.com",
      to: [ { "name" => "Marie Novák", "address" => "marie@example.com" }, { "name" => nil, "address" => "bob@example.com" } ])
    index_contact_message(uid: 2, from_name: "Marie Novák", from_address: "marie@example.com")
    index_contact_message(uid: 3, from_name: "Me", from_address: "one@example.com",
      to: [ { "name" => "Marie Novák", "address" => "Marie@Example.com" } ], cc: [ { "name" => "Bob", "address" => "bob@example.com" } ])

    all = contacts(query: "example.com")

    assert_equal [ [ "marie@example.com", 3, "both" ], [ "bob@example.com", 2, "to" ], [ "one@example.com", 2, "from" ] ],
      all.map { |c| c.values_at("address", "messages_count", "direction") }
    assert_equal 1, contacts(query: "example.com", limit: 1).size
  end

  test "search_contacts never reaches another user's mail and refuses their account id" do
    index_contact_message(uid: 1, from_name: "Marie Novák", from_address: "marie@example.com", account: mail_accounts(:personal))

    assert_empty contacts(query: "marie")
    result = call_tool("search_contacts", account_id: mail_accounts(:personal).id, query: "marie")
    assert result["isError"]
    assert_not_includes result.to_json, "marie@example.com"
    assert_equal "denied", McpAuditEvent.last.outcome
  end

  test "search_contacts counts as one search against the search budget" do
    McpSearchGuard::SEARCHES.consume(mail_accounts(:work), McpSearchGuard::SEARCHES.to)

    result = call_tool("search_contacts", account_id: mail_accounts(:work).id, query: "marie")

    assert result["isError"]
    assert_equal "search_limited", McpAuditEvent.last.outcome
  end

  test "search_contacts asks for something to look for" do
    result = call_tool("search_contacts", account_id: mail_accounts(:work).id, query: "  ")

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "name or an address"
  end

  test "get_message returns headers and the plain text body, and audits one row" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: plain_body("Ahoj, jak se máš?"),
      to_addresses: [ { "name" => nil, "address" => "bob@example.com" } ],
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 12_345 } ])

    payload = get_message(id: message.id)

    assert_equal "Ahoj, jak se máš?", payload["body"].strip
    assert_equal false, payload["truncated"]
    assert_equal "bob@example.com", payload["to"].sole
    assert_equal [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 12_345 } ], payload["attachments"]
    assert_equal [ "get_message", "ok", 1 ], McpAuditEvent.sole.values_at(:tool_name, :outcome, :rows_returned)
  ensure
    server&.stop
  end

  test "get_message converts an html-only body to text instead of handing back markup" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: html_body("<p>Řádek jedna</p><p>Řádek dva</p>"))

    payload = get_message(id: message.id)

    assert_equal "Řádek jedna\nŘádek dva", payload["body"].strip
  ensure
    server&.stop
  end

  test "get_message never reaches another user's mail" do
    message = index_message(mail_accounts(:personal), uid: 1, subject: "Not yours")

    result = call_tool("get_message", id: message.id)

    assert result["isError"]
    assert_not_includes result.to_json, "Not yours"
  end

  test "get_message asks for an id when none is given" do
    result = call_tool("get_message", id: nil)

    assert result["isError"]
  end

  test "get_message explains a message that no longer exists" do
    result = call_tool("get_message", id: MailMessage.maximum(:id).to_i + 1)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "No message"
  end

  test "get_message explains when the indexed message is no longer on the server" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: plain_body("hi"), uidvalidity: 1)
    # The server has since re-issued UIDVALIDITY (e.g. the mailbox was rebuilt), so the row
    # search_messages handed out no longer identifies a real message.
    @fake_mailboxes["INBOX"][:uidvalidity] = 999

    result = call_tool("get_message", id: message.id)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "no longer on the server"
  ensure
    server&.stop
  end

  test "get_message truncates a very long body and says so" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: plain_body("a" * (McpTools::GetMessage::BODY_CHAR_LIMIT + 500)))

    payload = get_message(id: message.id)

    assert_equal McpTools::GetMessage::BODY_CHAR_LIMIT, payload["body"].length
    assert_equal true, payload["truncated"]
    assert_includes payload["note"], "cut off"
  ensure
    server&.stop
  end

  test "get_attachment returns metadata and a working download url, never the bytes" do
    message = index_message(mail_accounts(:work), uid: 1, subject: "Faktura",
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 12_345 } ])

    payload = get_attachment(message_id: message.id, attachment_index: 0)

    assert_equal [ message.id, 0, "faktura.pdf", "application/pdf", 12_345 ],
      payload.values_at("message_id", "attachment_index", "filename", "content_type", "size")
    assert_equal %w[attachment_index content_type expires_in_seconds filename message_id size url], payload.keys.sort
    assert_match %r{\Ahttp://[^/]+/attachment-downloads/}, payload["url"]
    assert_equal [ "get_attachment", "ok", 1 ], McpAuditEvent.sole.values_at(:tool_name, :outcome, :rows_returned)
  end

  test "get_attachment with inline returns the bytes as base64 over the MCP connection, no url" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: multipart_body(content: "%PDF-1.4 faktura", filename: "faktura.pdf"),
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 16 } ])

    payload = get_attachment(message_id: message.id, attachment_index: 0, inline: true)

    assert_equal %w[attachment_index content_base64 content_type filename message_id size], payload.keys.sort
    assert_equal "%PDF-1.4 faktura", Base64.strict_decode64(payload["content_base64"])
    assert_equal [ "faktura.pdf", "application/pdf", 16 ], payload.values_at("filename", "content_type", "size")
    audit = McpAuditEvent.sole
    assert_equal [ "get_attachment", "ok", 1 ], audit.values_at(:tool_name, :outcome, :rows_returned)
    assert_not_includes audit.attributes.to_json, payload["content_base64"]
  ensure
    server&.stop
  end

  test "get_attachment with inline refuses above the inline limit before touching IMAP, pointing at the url mode" do
    message = index_message(mail_accounts(:work), uid: 1, subject: "Faktura",
      attachments: [ { "filename" => "scan.pdf", "content_type" => "application/pdf", "size" => McpTools::GetAttachment::MAX_INLINE_BYTES + 1 } ])

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0, inline: true)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "without inline"
  end

  test "get_attachment with inline refuses a fetched file larger than the index said" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1,
      body: multipart_body(content: "a" * (McpTools::GetAttachment::MAX_INLINE_BYTES + 1), filename: "scan.pdf"),
      attachments: [ { "filename" => "scan.pdf", "content_type" => "application/pdf", "size" => 1 } ])

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0, inline: true)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "without inline"
  ensure
    server&.stop
  end

  test "get_attachment with inline says so when the message is gone from the server" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: multipart_body(content: "abc", filename: "faktura.pdf"),
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 3 } ])
    @fake_mailboxes["INBOX"][:messages].clear

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0, inline: true)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "no longer on the server"
  ensure
    server&.stop
  end

  test "get_attachment with inline never reaches another user's mail" do
    message = index_message(mail_accounts(:personal), uid: 1, subject: "Not yours",
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 100 } ])

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0, inline: true)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "No message"
  end

  test "get_attachment refuses an attachment above its size limit" do
    message = index_message(mail_accounts(:work), uid: 1, subject: "Faktura",
      attachments: [ { "filename" => "big.zip", "content_type" => "application/zip", "size" => McpTools::GetAttachment::MAX_ATTACHMENT_BYTES + 1 } ])

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "maximum"
  end

  test "get_attachment refuses an index that does not exist" do
    message = index_message(mail_accounts(:work), uid: 1, subject: "No attachments")

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0)

    assert result["isError"]
    assert_includes result.dig("content", 0, "text"), "No attachment"
  end

  test "get_attachment refuses a negative index" do
    message = index_message(mail_accounts(:work), uid: 1, subject: "Faktura",
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 100 } ])

    result = call_tool("get_attachment", message_id: message.id, attachment_index: -1)

    assert result["isError"]
  end

  test "get_attachment never reaches another user's mail" do
    message = index_message(mail_accounts(:personal), uid: 1, subject: "Not yours",
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 100 } ])

    result = call_tool("get_attachment", message_id: message.id, attachment_index: 0)

    assert result["isError"]
  end

  private
    def contacts(**arguments)
      result = call_tool("search_contacts", account_id: mail_accounts(:work).id, **arguments)

      assert_not result["isError"], result.to_json
      JSON.parse(result.dig("content", 0, "text")).fetch("contacts")
    end

    def index_contact_message(uid:, from_name:, from_address:, to: [], cc: [], date: Time.current, account: mail_accounts(:work))
      folder = account.mail_folders.find_or_create_by!(name: "INBOX") { |new_folder| new_folder.uidvalidity = 1 }
      account.mail_messages.create!(
        mail_folder: folder, uidvalidity: 1, uid:, subject: "Hi", date:, from_name:, from_address:,
        to_addresses: to, cc_addresses: cc,
        search_text: MailMessage.build_search_text(subject: "Hi", from_name:, from_address:, to_addresses: to, cc_addresses: cc)
      )
    end

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

    def get_message(**arguments)
      result = call_tool("get_message", **arguments)

      assert_not result["isError"], result.to_json
      JSON.parse(result.dig("content", 0, "text"))
    end

    def get_attachment(**arguments)
      result = call_tool("get_attachment", **arguments)

      assert_not result["isError"], result.to_json
      JSON.parse(result.dig("content", 0, "text"))
    end

    # A MailAccount pointed at a real, in-process FakeImapServer, so get_message can actually
    # fetch a body over IMAP instead of just reading the local index. index_body_message adds
    # messages to the same mailboxes hash the server was started with.
    def start_fake_account
      @fake_mailboxes = { "INBOX" => { uidvalidity: 1, messages: [] } }
      server = FakeImapServer.new(mailboxes: @fake_mailboxes).start
      account = @user.mail_accounts.create!(
        host: "127.0.0.1", port: server.port, ssl: false, username: "bob", password: "fixture-app-password"
      )
      [ server, account ]
    end

    # Indexes a message the way MessageSync would, and adds it to the fake server's mailbox so
    # the same uid/folder/uidvalidity resolves to a real body fetch.
    def index_body_message(account, uid:, body:, uidvalidity: 1, subject: "Subject", from_address: "sender@example.com",
      to_addresses: [], attachments: [])
      folder = account.mail_folders.find_or_create_by!(name: "INBOX") { |new_folder| new_folder.uidvalidity = uidvalidity }
      message = account.mail_messages.create!(
        mail_folder: folder, uidvalidity:, uid:, subject:, from_address:, to_addresses:, cc_addresses: [],
        has_attachments: attachments.any?, attachments:,
        search_text: MailMessage.build_search_text(subject:, from_name: nil, from_address:, to_addresses:, cc_addresses: [])
      )
      @fake_mailboxes["INBOX"][:messages] << { uid:, body: }
      message
    end

    def plain_body(text, charset: "UTF-8")
      "Content-Type: text/plain; charset=#{charset}\r\n\r\n#{text}".b
    end

    def html_body(html)
      "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}".b
    end

    def multipart_body(content:, filename:)
      <<~RAW.b
        Content-Type: multipart/mixed; boundary="BOUNDARY123"

        --BOUNDARY123
        Content-Type: text/plain; charset=UTF-8

        See attached.
        --BOUNDARY123
        Content-Type: application/pdf
        Content-Disposition: attachment; filename="#{filename}"
        Content-Transfer-Encoding: 7bit

        #{content}
        --BOUNDARY123--
      RAW
    end
end
