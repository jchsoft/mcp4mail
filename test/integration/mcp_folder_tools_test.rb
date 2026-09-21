require "net/imap"
require "test_helper"
require "hitch/mcp/test_helper"

class McpFolderToolsTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
  end

  teardown do
    McpQuota.store_override = nil
    @server&.stop
  end

  test "list_folders reports counts and special use, with names decoded" do
    start_server(
      folders: [ { name: "INBOX" }, { name: "Odesl&AOE-no", attrs: [ "Sent" ] }, { name: "Trash", attrs: [ "Trash" ] } ],
      mailboxes: {
        "INBOX" => { uidvalidity: 1, messages: [ { uid: 1 }, { uid: 2, flags: [ "\\Seen" ] } ] },
        "Odesl&AOE-no" => { uidvalidity: 2, messages: [] },
        "Trash" => { uidvalidity: 3, messages: [] }
      }
    )

    folders = tool_json("list_folders", account_id: @account.id)["folders"]

    assert_equal [ "INBOX", "Odeslano".sub("a", "á"), "Trash" ], folders.map { |folder| folder["name"] }
    assert_equal "Odesl&AOE-no", folders[1]["path"]
    assert_equal [ 2, 1, "inbox" ], folders[0].values_at("message_count", "unseen_count", "special_use")
    assert_equal %w[sent trash], folders.drop(1).map { |folder| folder["special_use"] }
    assert_equal [ "ok", 3 ], McpAuditEvent.sole.values_at(:outcome, :rows_returned)
  end

  test "list_folders needs no write switch" do
    start_server(folders: [ { name: "INBOX" } ], mailboxes: { "INBOX" => { uidvalidity: 1, messages: [] } })

    assert_not @account.writable?
    assert_not call_tool("list_folders", account_id: @account.id)["isError"]
  end

  test "create_folder is refused on a read-only mailbox and audited" do
    start_server

    result = call_tool("create_folder", account_id: @account.id, name: "Receipts")

    assert result["isError"]
    assert_equal McpTools::ApplicationTool::READ_ONLY_MAILBOX, result.dig("content", 0, "text")
    assert_equal "denied", McpAuditEvent.sole.outcome
    assert_not @server.commands.any? { |command| command.start_with?("CREATE") }
  end

  test "create_folder makes a folder, and asking again returns the same one" do
    start_server
    @account.update!(writable: true)

    first = tool_json("create_folder", account_id: @account.id, name: "Receipts")
    again = tool_json("create_folder", account_id: @account.id, name: "Receipts")

    assert_equal [ "Receipts", true ], first.values_at("path", "created")
    assert_equal [ "Receipts", false ], again.values_at("path", "created")
    assert_equal 1, @server.commands.count { |command| command.start_with?("CREATE") }
  end

  test "create_folder encodes non-ASCII names and nests under a parent" do
    start_server(folders: [ { name: "Work" } ], mailboxes: { "Work" => { uidvalidity: 1, messages: [] } })
    @account.update!(writable: true)

    folder = tool_json("create_folder", account_id: @account.id, name: "Faktury á", parent: "Work")

    assert_equal [ "Work/Faktury &AOE-", "Work/Faktury á" ], folder.values_at("path", "name")
  end

  test "create_folder retries under the namespace prefix when the plain name is refused" do
    start_server(capabilities: "IMAP4rev1 NAMESPACE", namespace_prefix: "INBOX.")
    @account.update!(writable: true)

    folder = tool_json("create_folder", account_id: @account.id, name: "Receipts")

    assert_equal "INBOX.Receipts", folder["path"]
    assert_equal [ "CREATE Receipts", "CREATE INBOX.Receipts" ], @server.commands.grep(/\ACREATE/).map { |command| command.delete('"') }
  end

  test "create_folder raises the server's refusal when there is no prefix to try" do
    start_server(namespace_prefix: "INBOX.")
    @account.update!(writable: true)

    result = call_tool("create_folder", account_id: @account.id, name: "Receipts")

    assert result["isError"]
    assert_match "refused", result.dig("content", 0, "text")
  end

  test "move_message uses UID MOVE when the server has MOVE and updates the index" do
    start_move_server(capabilities: "IMAP4rev1 MOVE UIDPLUS")

    result = tool_json("move_message", account_id: @account.id, message_id: @message.id, folder: "Archive")

    assert_equal [ true, "Archive" ], result.values_at("moved", "folder")
    assert @server.commands.any? { |command| command.start_with?("UID MOVE") }
    assert_not @server.commands.any? { |command| command.include?("EXPUNGE") }
    assert_equal [ @archive.id, 1, 200 ], @message.reload.values_at(:mail_folder_id, :uid, :uidvalidity)
    assert_equal [ 1 ], @mailboxes["Archive"][:messages].map { |m| m[:uid] }
    assert_empty @mailboxes["INBOX"][:messages]
  end

  test "move_message falls back to COPY, \\Deleted and UID EXPUNGE without MOVE" do
    start_move_server(capabilities: "IMAP4rev1 UIDPLUS")

    tool_json("move_message", account_id: @account.id, message_id: @message.id, folder: "Archive")

    commands = @server.commands.grep(/\AUID (COPY|STORE|EXPUNGE)/).map { |command| command.split.first(2).join(" ") }
    assert_equal [ "UID COPY", "UID STORE", "UID EXPUNGE" ], commands
    assert_equal [ @archive.id, 1 ], @message.reload.values_at(:mail_folder_id, :uid)
    assert_empty @mailboxes["INBOX"][:messages]
  end

  test "move_message without MOVE or UIDPLUS refuses rather than expunge other messages" do
    start_move_server(capabilities: "IMAP4rev1")

    result = call_tool("move_message", account_id: @account.id, message_id: @message.id, folder: "Archive")

    assert result["isError"]
    assert_not @server.commands.any? { |command| command.start_with?("UID COPY") }
    assert_equal 7, @message.reload.uid
  end

  test "move_message accepts a special-use name and reports an unknown folder" do
    start_move_server(capabilities: "IMAP4rev1 MOVE UIDPLUS")

    missing = call_tool("move_message", account_id: @account.id, message_id: @message.id, folder: "Nowhere")
    assert missing["isError"]
    assert_match "list_folders", missing.dig("content", 0, "text")

    tool_json("move_message", account_id: @account.id, message_id: @message.id, folder: "archive")
    assert_equal @archive.id, @message.reload.mail_folder_id
  end

  test "move_message is refused on a read-only mailbox" do
    start_move_server(capabilities: "IMAP4rev1 MOVE UIDPLUS")
    @account.update!(writable: false)

    result = call_tool("move_message", account_id: @account.id, message_id: @message.id, folder: "Archive")

    assert result["isError"]
    assert_equal McpTools::ApplicationTool::READ_ONLY_MAILBOX, result.dig("content", 0, "text")
    assert_equal @inbox.id, @message.reload.mail_folder_id
  end

  test "set_flags flags a message and updates the index" do
    start_flags_server

    result = tool_json("set_flags", account_id: @account.id, message_id: @message.id, flagged: true)

    assert_equal [ true, false ], result.values_at("flagged", "seen")
    assert_equal [ "Flagged" ], @message.reload.flags
    assert @server.commands.any? { |command| command.start_with?("SELECT") }
    assert_not @server.commands.any? { |command| command.start_with?("EXAMINE") }
    assert_equal [ "\\Flagged" ], @mailboxes["INBOX"][:messages].first[:flags]
  end

  test "set_flags marks read and unread" do
    start_flags_server(flags: [ "\\Flagged" ])
    @message.update!(flags: [ "Flagged" ])

    seen = tool_json("set_flags", account_id: @account.id, message_id: @message.id, seen: true)
    assert_equal [ true, true ], seen.values_at("flagged", "seen")

    unseen = tool_json("set_flags", account_id: @account.id, message_id: @message.id, seen: false)
    assert_equal [ true, false ], unseen.values_at("flagged", "seen")
    assert_equal [ "Flagged" ], @message.reload.flags
  end

  test "set_flags sets both flags in one call" do
    start_flags_server(flags: [ "\\Seen" ])
    @message.update!(flags: [ "Seen" ])

    result = tool_json("set_flags", account_id: @account.id, message_id: @message.id, flagged: true, seen: false)

    assert_equal [ true, false ], result.values_at("flagged", "seen")
    assert_equal [ "Flagged" ], @message.reload.flags
  end

  test "set_flags needs at least one flag" do
    start_flags_server

    result = call_tool("set_flags", account_id: @account.id, message_id: @message.id)

    assert result["isError"]
    assert_not @server.commands.any? { |command| command.include?("STORE") }
  end

  test "set_flags is refused on a read-only mailbox and audited" do
    start_flags_server
    @account.update!(writable: false)

    result = call_tool("set_flags", account_id: @account.id, message_id: @message.id, flagged: true)

    assert result["isError"]
    assert_equal McpTools::ApplicationTool::READ_ONLY_MAILBOX, result.dig("content", 0, "text")
    assert_equal "denied", McpAuditEvent.sole.outcome
    assert_empty @message.reload.flags
  end

  test "set_flags reports an unknown message" do
    start_flags_server

    result = call_tool("set_flags", account_id: @account.id, message_id: 0, flagged: true)

    assert result["isError"]
    assert_match "No message", result.dig("content", 0, "text")
  end

  test "set_flags raises when the server answers NO to the STORE" do
    start_flags_server(refuse_store: true)

    assert_raises(Net::IMAP::NoResponseError) do
      Imap::FlagSetter.call(@message, flagged: true)
    end
    assert_empty @message.reload.flags
  end

  test "trash_message moves to the special-use Trash folder and never expunges" do
    start_trash_server(folders: [ { name: "INBOX" }, { name: "Bin", attrs: [ "Trash" ] } ], trash: "Bin")

    result = tool_json("trash_message", account_id: @account.id, message_id: @message.id)

    assert_equal [ true, "Bin" ], result.values_at("trashed", "folder")
    assert @server.commands.any? { |command| command.start_with?("UID MOVE") }
    assert_not @server.commands.any? { |command| command.include?("EXPUNGE") }
    assert_equal @trash.id, @message.reload.mail_folder_id
  end

  test "trash_message finds a localized Trash folder by name" do
    start_trash_server(folders: [ { name: "INBOX" }, { name: "Ko&AWE-" } ], trash: "Ko&AWE-")

    result = tool_json("trash_message", account_id: @account.id, message_id: @message.id)

    assert_equal [ "Ko\u0161", "Ko&AWE-" ], result.values_at("folder", "path")
    assert_equal @trash.id, @message.reload.mail_folder_id
  end

  test "trash_message refuses when there is no Trash folder" do
    start_trash_server(folders: [ { name: "INBOX" }, { name: "Archive" } ], trash: "Archive")

    result = call_tool("trash_message", account_id: @account.id, message_id: @message.id)

    assert result["isError"]
    assert_match "no Trash folder", result.dig("content", 0, "text")
    assert_not @server.commands.any? { |command| command.start_with?("UID MOVE", "UID COPY", "CREATE") }
    assert_equal @inbox.id, @message.reload.mail_folder_id
  end

  test "trash_message on a message already in Trash does nothing" do
    start_trash_server(folders: [ { name: "INBOX" }, { name: "Trash", attrs: [ "Trash" ] } ], trash: "Trash")
    @message.update!(mail_folder: @trash)

    result = tool_json("trash_message", account_id: @account.id, message_id: @message.id)

    assert_equal "Trash", result["folder"]
    assert_not @server.commands.any? { |command| command.start_with?("UID MOVE", "UID COPY", "UID STORE") }
  end

  test "trash_message is refused on a read-only mailbox and audited" do
    start_trash_server(folders: [ { name: "INBOX" }, { name: "Trash", attrs: [ "Trash" ] } ], trash: "Trash")
    @account.update!(writable: false)

    result = call_tool("trash_message", account_id: @account.id, message_id: @message.id)

    assert result["isError"]
    assert_equal McpTools::ApplicationTool::READ_ONLY_MAILBOX, result.dig("content", 0, "text")
    assert_equal "denied", McpAuditEvent.sole.outcome
    assert_equal @inbox.id, @message.reload.mail_folder_id
  end

  private
    def start_server(writable: false, **options)
      @server = FakeImapServer.new(**options).start
      @account = @user.mail_accounts.create!(
        host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable:
      )
    end

    def start_move_server(capabilities:)
      @mailboxes = {
        "INBOX" => { uidvalidity: 100, messages: [ { uid: 7 } ] },
        "Archive" => { uidvalidity: 200, messages: [] }
      }
      start_server(
        writable: true, capabilities:, mailboxes: @mailboxes,
        folders: [ { name: "INBOX" }, { name: "Archive", attrs: [ "Archive" ] } ]
      )
      @inbox = @account.mail_folders.create!(name: "INBOX", uidvalidity: 100)
      @archive = @account.mail_folders.create!(name: "Archive", uidvalidity: 200)
      @message = MailMessage.create!(
        mail_account: @account, mail_folder: @inbox, uidvalidity: 100, uid: 7, subject: "Hi",
        from_address: "a@example.com", to_addresses: [], cc_addresses: [], search_text: "hi"
      )
    end

    def start_trash_server(folders:, trash:)
      @mailboxes = { "INBOX" => { uidvalidity: 100, messages: [ { uid: 7 } ] }, trash => { uidvalidity: 200, messages: [] } }
      start_server(writable: true, capabilities: "IMAP4rev1 MOVE UIDPLUS", mailboxes: @mailboxes, folders:)
      @inbox = @account.mail_folders.create!(name: "INBOX", uidvalidity: 100)
      @trash = @account.mail_folders.create!(name: trash, uidvalidity: 200)
      @message = MailMessage.create!(
        mail_account: @account, mail_folder: @inbox, uidvalidity: 100, uid: 7, subject: "Hi",
        from_address: "a@example.com", to_addresses: [], cc_addresses: [], search_text: "hi"
      )
    end

    def start_flags_server(flags: [], refuse_store: false)
      @mailboxes = { "INBOX" => { uidvalidity: 100, messages: [ { uid: 7, flags: } ] } }
      start_server(writable: true, mailboxes: @mailboxes, folders: [ { name: "INBOX" } ], refuse_store:)
      @inbox = @account.mail_folders.create!(name: "INBOX", uidvalidity: 100)
      @message = MailMessage.create!(
        mail_account: @account, mail_folder: @inbox, uidvalidity: 100, uid: 7, subject: "Hi",
        from_address: "a@example.com", to_addresses: [], cc_addresses: [], search_text: "hi"
      )
    end

    def call_tool(name, **arguments)
      post_mcp(method: "tools/call", token: @token, params: { name:, arguments: })

      assert_response :success
      response.parsed_body.fetch("result")
    end

    def tool_json(name, **arguments)
      result = call_tool(name, **arguments)

      assert_not result["isError"], result.to_json
      JSON.parse(result.dig("content", 0, "text"))
    end
end
