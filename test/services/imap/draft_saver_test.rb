require "test_helper"
require "net/imap"

class Imap::DraftSaverTest < ActiveSupport::TestCase
  setup do
    @mailboxes = { "INBOX" => { uidvalidity: 111, messages: [] } }
  end

  teardown { @server&.stop }

  def start_server(folders: [], capabilities: "IMAP4rev1 UIDPLUS SPECIAL-USE")
    @server = FakeImapServer.new(capabilities:, mailboxes: @mailboxes, folders: [ { name: "INBOX", attrs: %w[HasNoChildren] } ] + folders).start
    @account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable: true)
  end

  def save(**fields)
    Imap::DraftSaver.call(@account, to: [ "ann@example.com" ], subject: "Hi", body: "Hello", **fields)
  end

  test "appends to the SPECIAL-USE Drafts folder and indexes the draft" do
    @mailboxes["Entwuerfe"] = { uidvalidity: 222, messages: [] }
    start_server(folders: [ { name: "Entwuerfe", attrs: %w[HasNoChildren Drafts] } ])

    result = save

    assert_equal "Entwuerfe", result.folder
    assert_equal [ [ "\\Draft" ] ], @mailboxes["Entwuerfe"][:messages].map { |m| m[:flags] }
    assert_equal [ "Draft" ], result.message.flags
    assert_equal [ "ann@example.com" ], result.message.to_addresses.map { |a| a["address"] }
    assert_equal "Hi", result.message.subject
  end

  test "finds a Drafts folder by its name in another language" do
    @mailboxes["Koncepty"] = { uidvalidity: 222, messages: [] }
    start_server(folders: [ { name: "Koncepty", attrs: %w[HasNoChildren] } ])

    assert_equal "Koncepty", save.folder
  end

  test "creates a Drafts folder when the server has none" do
    start_server

    result = save

    assert_equal "Drafts", result.folder
    assert_equal 1, @mailboxes["Drafts"][:messages].size
  end

  test "without UIDPLUS the draft is saved but not indexed until the next sync" do
    start_server(capabilities: "IMAP4rev1")

    result = save

    assert_nil result.message
    assert_equal 1, @mailboxes["Drafts"][:messages].size
    assert_equal 0, @account.mail_messages.count
  end

  test "indexes cc recipients and the message this one replies to" do
    start_server
    original = @account.mail_folders.create!(name: "INBOX", uidvalidity: 111).then do |folder|
      @account.mail_messages.create!(mail_folder: folder, uid: 1, uidvalidity: 111, message_id: "<orig@example.com>", subject: "Original")
    end

    result = save(cc: [ "Cy <cy@example.com>" ], reply_to: original, subject: nil)

    assert_equal [ "cy@example.com" ], result.message.cc_addresses.map { |a| a["address"] }
    assert_equal "Re: Original", result.message.subject
    assert_equal "<orig@example.com>", result.message.in_reply_to
  end

  test "an invalid recipient is rejected before any connection is made" do
    start_server

    assert_raises(Imap::DraftSaver::Invalid) { save(to: [ "not-an-address" ]) }
    assert_empty @server.commands
  end

  test "a server that refuses to create the Drafts folder raises" do
    start_server(capabilities: "IMAP4rev1 UIDPLUS")
    @server.stop
    @server = FakeImapServer.new(capabilities: "IMAP4rev1 UIDPLUS", mailboxes: @mailboxes, namespace_prefix: "INBOX.").start
    @account.update!(port: @server.port)

    assert_raises(Net::IMAP::NoResponseError) { save }
    assert_equal 0, @account.mail_messages.count
  end
end
