require "net/imap"
require "test_helper"
require "hitch/mcp/test_helper"

# What the AI is told when a tool cannot do its job: the message is gone from the server, the
# server refuses, or the server cannot be reached. The happy paths live in the other mcp_*_test files.
class McpToolErrorPathsTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper
  include ActionMailer::TestHelper

  GONE = "This message is no longer on the server. Run search_messages again to get a fresh id."
  UNREACHABLE = "Could not reach the mail server"
  MOVE_SERVER = { capabilities: "IMAP4rev1 UIDPLUS", folders: [ { name: "INBOX" }, { name: "Trash", attrs: [ "Trash" ] }, { name: "Archive", attrs: [ "Archive" ] } ] }.freeze

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
  end

  teardown do
    McpQuota.store_override = nil
    @server&.stop
  end

  # message gone: the UID was deleted on the server after it was indexed

  test "trash_message, move_message and set_flags tell the AI to search again when the message is gone" do
    start_account(**MOVE_SERVER, writable: true)
    forget_on_server

    [
      [ "trash_message", {} ],
      [ "move_message", { folder: "Archive" } ],
      [ "set_flags", { flagged: true } ]
    ].each do |name, arguments|
      result = call_tool(name, account_id: @account.id, message_id: @message.id, **arguments)

      assert result["isError"], name
      assert_equal GONE, text_of(result), name
    end
  end

  test "get_message and get_attachment tell the AI to search again when the message is gone" do
    start_account
    @message.update!(attachments: [ { "filename" => "a.pdf", "content_type" => "application/pdf", "size" => 4 } ])
    forget_on_server

    message = call_tool("get_message", id: @message.id)
    attachment = call_tool("get_attachment", message_id: @message.id, attachment_index: 0, inline: true)

    assert_equal [ true, GONE ], [ message["isError"], text_of(message) ]
    assert_equal [ true, "This message or attachment is no longer on the server. Run search_messages again to get a fresh id." ],
      [ attachment["isError"], text_of(attachment) ]
  end

  # the server refused

  test "trash_message and move_message report a server that refuses the move" do
    start_account(**MOVE_SERVER, writable: true, refuse_store: true)

    trash = call_tool("trash_message", account_id: @account.id, message_id: @message.id)
    move = call_tool("move_message", account_id: @account.id, message_id: @message.id, folder: "Archive")

    assert_match "The mail server refused the move to Trash", text_of(trash)
    assert_match "The mail server refused the move:", text_of(move)
    assert_equal [ true, true ], [ trash["isError"], move["isError"] ]
    assert_equal @inbox.id, @message.reload.mail_folder_id
  end

  test "create_folder reports a server that refuses to create the folder" do
    start_account(writable: true, namespace_prefix: "INBOX.")

    result = call_tool("create_folder", account_id: @account.id, name: "Receipts")

    assert result["isError"]
    assert_match "The mail server refused to create the folder", text_of(result)
  end

  test "create_draft reports a server that refuses to save the draft" do
    start_account(writable: true, namespace_prefix: "INBOX.", capabilities: "IMAP4rev1 UIDPLUS")

    result = call_tool("create_draft", account_id: @account.id, to: "amy@example.com", body: "Hi")

    assert result["isError"]
    assert_match "The mail server refused to save the draft", text_of(result)
  end

  test "set_flags re-raises a refused STORE, so the AI gets the generic failure and the audit says error" do
    start_account(writable: true, refuse_store: true)

    result = call_tool("set_flags", account_id: @account.id, message_id: @message.id, flagged: true)

    assert result["isError"]
    assert_equal Hitch::MCP::Protocol::GENERIC_TOOL_ERROR, text_of(result)
    assert_equal "error", McpAuditEvent.sole.outcome
    assert_empty @message.reload.flags
  end

  # connection lost: the server's port is closed

  test "every tool that talks to the server says it could not reach it" do
    start_account(**MOVE_SERVER, writable: true)
    @message.update!(attachments: [ { "filename" => "a.pdf", "content_type" => "application/pdf", "size" => 4 } ])
    @server.stop

    {
      "list_folders" => { account_id: @account.id },
      "get_message" => { id: @message.id },
      "get_attachment" => { message_id: @message.id, attachment_index: 0, inline: true },
      "create_folder" => { account_id: @account.id, name: "Receipts" },
      "create_draft" => { account_id: @account.id, to: "amy@example.com", body: "Hi" },
      "trash_message" => { account_id: @account.id, message_id: @message.id },
      "move_message" => { account_id: @account.id, message_id: @message.id, folder: "Archive" },
      "set_flags" => { account_id: @account.id, message_id: @message.id, flagged: true }
    }.each do |name, arguments|
      result = call_tool(name, **arguments)

      assert result["isError"], name
      assert_includes text_of(result), UNREACHABLE, name
    end
  end

  # get_message

  test "get_message renders the cc addresses" do
    start_account
    @message.update!(cc_addresses: [ { "name" => "Cy Copy", "address" => "cy@example.com" }, { "name" => nil, "address" => "di@example.com" } ])

    cc = JSON.parse(text_of(call_tool("get_message", id: @message.id)))["cc"]

    assert_equal 2, cc.size
    assert_includes cc.first, "Cy Copy"
    assert_includes cc.first, "cy@example.com"
    assert_includes cc.last, "di@example.com"
  end

  # send_message

  test "send_message replies to a message of the mailbox and refuses an unknown one" do
    start_account(writable: true)

    ok = call_tool("send_message", account_id: @account.id, to: "amy@example.com", body: "Hi", reply_to_message_id: @message.id)
    unknown = call_tool("send_message", account_id: @account.id, to: "amy@example.com", body: "Hi", reply_to_message_id: 0)

    assert_not ok["isError"], ok.to_json
    assert_equal @message.subject, OutgoingMessage.find(JSON.parse(text_of(ok))["outgoing_message_id"]).subject.delete_prefix("Re: ")
    assert unknown["isError"]
    assert_equal "No message with that id in this mailbox.", text_of(unknown)
    assert_equal 1, OutgoingMessage.count
  end

  test "send_message sends a saved draft, with the fields it is given replacing the draft's" do
    start_account(writable: true)
    draft = index_message(uid: 8, subject: "Draft subject", body: "Draft body", to_addresses: [ { "name" => nil, "address" => "amy@example.com" } ])

    plain = JSON.parse(text_of(call_tool("send_message", account_id: @account.id, draft_message_id: draft.id)))
    replaced = JSON.parse(text_of(call_tool("send_message", account_id: @account.id, draft_message_id: draft.id, subject: "New subject", to: "bo@example.com")))

    first = OutgoingMessage.find(plain["outgoing_message_id"])
    second = OutgoingMessage.find(replaced["outgoing_message_id"])
    assert_equal [ [ "amy@example.com" ], "Draft subject", "Draft body" ], [ first.to_addresses, first.subject, first.body.strip ]
    assert_equal [ [ "bo@example.com" ], "New subject", "Draft body" ], [ second.to_addresses, second.subject, second.body.strip ]
  end

  test "send_message refuses a draft id that is not in the mailbox" do
    start_account(writable: true)

    result = call_tool("send_message", account_id: @account.id, draft_message_id: 0)

    assert result["isError"]
    assert_equal "No draft with that id in this mailbox.", text_of(result)
  end

  test "send_message says so when the draft is gone from the server" do
    start_account(writable: true)
    draft = index_message(uid: 8, subject: "Draft subject", body: "Draft body")
    @mailboxes["INBOX"][:messages].reject! { |m| m[:uid] == 8 }

    result = call_tool("send_message", account_id: @account.id, to: "amy@example.com", draft_message_id: draft.id)

    assert result["isError"]
    assert_equal "That draft is no longer on the server. Run search_messages again to get a fresh id.", text_of(result)
    assert_equal 0, OutgoingMessage.count
  end

  test "send_message says so when the server holding the draft is unreachable" do
    start_account(writable: true)
    draft = index_message(uid: 8, subject: "Draft subject", body: "Draft body")
    @server.stop

    result = call_tool("send_message", account_id: @account.id, to: "amy@example.com", draft_message_id: draft.id)

    assert result["isError"]
    assert_includes text_of(result), UNREACHABLE
    assert_equal 0, OutgoingMessage.count
  end

  private
    def start_account(writable: false, **server_options)
      @mailboxes = { "INBOX" => { uidvalidity: 100, messages: [] }, "Trash" => { uidvalidity: 200, messages: [] }, "Archive" => { uidvalidity: 300, messages: [] } }
      @server = FakeImapServer.new(mailboxes: @mailboxes, **{ folders: [ { name: "INBOX" } ] }.merge(server_options)).start
      @account = @user.mail_accounts.create!(host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable:)
      @inbox = @account.mail_folders.create!(name: "INBOX", uidvalidity: 100)
      @message = index_message(uid: 7, subject: "Hi", body: "Hello")
    end

    def index_message(uid:, subject:, body:, to_addresses: [])
      @mailboxes["INBOX"][:messages] << { uid:, body: "Content-Type: text/plain; charset=UTF-8\r\n\r\n#{body}".b }
      @account.mail_messages.create!(
        mail_folder: @inbox, uidvalidity: 100, uid:, subject:, from_address: "a@example.com", to_addresses:, cc_addresses: [],
        message_id: "<#{uid}@example.com>", search_text: subject.downcase
      )
    end

    def forget_on_server
      @mailboxes["INBOX"][:messages].clear
    end

    def text_of(result)
      result.dig("content", 0, "text")
    end

    def call_tool(name, **arguments)
      post_mcp(method: "tools/call", token: @token, params: { name:, arguments: })

      assert_response :success
      response.parsed_body.fetch("result")
    end
end
