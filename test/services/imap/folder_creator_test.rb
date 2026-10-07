require "test_helper"
require "net/imap"

class Imap::FolderCreatorTest < ActiveSupport::TestCase
  setup do
    @mailboxes = { "INBOX" => { uidvalidity: 111, messages: [] } }
  end

  teardown { @server&.stop }

  def start_server(**options)
    @server = FakeImapServer.new(
      **{ capabilities: "IMAP4rev1 NAMESPACE", mailboxes: @mailboxes, folders: [ { name: "INBOX", attrs: %w[HasNoChildren] } ] }.merge(options)
    ).start
    @account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable: true)
  end

  def create(name, parent: nil)
    Imap::FolderCreator.call(@account, name:, parent:)
  end

  test "creates a folder and reports it as new" do
    start_server

    result = create("Receipts")

    assert_equal "Receipts", result.path
    assert result.created
    assert_includes @mailboxes.keys, "Receipts"
  end

  test "a folder that already exists is returned, not created again" do
    start_server
    create("Receipts")

    result = create("Receipts")

    assert_not result.created
    assert_equal "Receipts", result.path
  end

  test "creates a nested folder under a parent given by path" do
    start_server
    create("Work")

    result = create("2026", parent: "Work")

    assert_equal "Work/2026", result.path
    assert_equal "/", result.delimiter
    assert_includes @mailboxes.keys, "Work/2026"
  end

  test "a parent that is not listed is used as given" do
    start_server

    assert_equal "Nowhere/Sub", create("Sub", parent: "Nowhere").path
  end

  test "encodes a non-ASCII name as modified UTF-7 and reports it readable" do
    start_server

    result = create("Účtenky")

    assert_equal Net::IMAP.encode_utf7("Účtenky"), result.path
    assert_equal "Účtenky", result.name
  end

  test "retries under the namespace prefix when the plain name is refused" do
    start_server(namespace_prefix: "INBOX.")

    result = create("Receipts")

    assert_equal "INBOX.Receipts", result.path
    assert result.created
    assert_includes @mailboxes.keys, "INBOX.Receipts"
  end

  test "a prefixed folder that already exists is returned as it is" do
    start_server(namespace_prefix: "INBOX.")
    create("Receipts")

    assert_equal "INBOX.Receipts", create("Receipts").path
  end

  test "raises the server refusal when the server has no NAMESPACE to retry under" do
    start_server(namespace_prefix: "INBOX.", capabilities: "IMAP4rev1")

    assert_raises(Net::IMAP::NoResponseError) { create("Receipts") }
  end
end
