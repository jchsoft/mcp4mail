require "test_helper"

class Imap::MessageMoverTest < ActiveSupport::TestCase
  setup do
    @mailboxes = {
      "INBOX" => { uidvalidity: 111, messages: [ { uid: 1, flags: [] }, { uid: 2, flags: [] } ] },
      "Archive" => { uidvalidity: 222, messages: [] },
      "Trash" => { uidvalidity: 333, messages: [] }
    }
  end

  teardown { @server&.stop }

  def start_server(capabilities: "IMAP4rev1 UIDPLUS MOVE")
    @server = FakeImapServer.new(
      capabilities:, mailboxes: @mailboxes,
      folders: [ { name: "INBOX" }, { name: "Archive", attrs: %w[Archive] }, { name: "Trash", attrs: %w[Trash] } ]
    ).start
    @account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable: true)
    @inbox = @account.mail_folders.create!(name: "INBOX", uidvalidity: 111)
    @archive = @account.mail_folders.create!(name: "Archive", uidvalidity: 222)
  end

  def build_message(uid: 1, uidvalidity: 111)
    @account.mail_messages.create!(mail_folder: @inbox, uid:, uidvalidity:)
  end

  test "moves with UID MOVE and re-keys the local row to the new UID" do
    start_server
    row = build_message

    result = Imap::MessageMover.call(row, to: "Archive")

    assert result.moved
    assert_equal [ 1 ], @mailboxes["Archive"][:messages].map { |m| m[:uid] }
    assert_equal [ 2 ], @mailboxes["INBOX"][:messages].map { |m| m[:uid] }
    assert_equal [ @archive, 1, 222 ], row.reload.then { |r| [ r.mail_folder, r.uid, r.uidvalidity ] }
  end

  test "finds the destination by special-use name or readable name, case-insensitively" do
    start_server

    assert_equal "Archive", Imap::MessageMover.call(build_message, to: "archive").folder
    assert_equal "Trash", Imap::MessageMover.call(build_message(uid: 2), to: "TRASH").folder
  end

  test "moving to the folder it is already in does nothing" do
    start_server

    result = Imap::MessageMover.call(build_message, to: "INBOX")

    assert_not result.moved
    assert_equal 2, @mailboxes["INBOX"][:messages].size
  end

  test "destroys the local row when the destination folder is not indexed yet" do
    start_server
    @archive.destroy!
    row = build_message

    Imap::MessageMover.call(row, to: "Archive")

    assert_not MailMessage.exists?(row.id)
    assert_equal 1, @mailboxes["Archive"][:messages].size
  end

  test "destroys the local row when the destination UIDVALIDITY differs from the indexed one" do
    start_server
    @archive.update!(uidvalidity: 999)
    row = build_message

    Imap::MessageMover.call(row, to: "Archive")

    assert_not MailMessage.exists?(row.id)
  end

  test "without MOVE it copies, flags \\Deleted and expunges just that UID" do
    start_server(capabilities: "IMAP4rev1 UIDPLUS")
    row = build_message

    Imap::MessageMover.call(row, to: "Archive")

    assert_equal [ 2 ], @mailboxes["INBOX"][:messages].map { |m| m[:uid] }
    assert_equal 1, @mailboxes["Archive"][:messages].size
    assert_equal "Archive", row.reload.mail_folder.name
  end

  test "refuses to move when the server has neither MOVE nor UIDPLUS" do
    start_server(capabilities: "IMAP4rev1")

    assert_raises(Imap::MessageMover::CannotMoveSafely) { Imap::MessageMover.call(build_message, to: "Archive") }
    assert_equal 2, @mailboxes["INBOX"][:messages].size
  end

  test "raises FolderNotFound for an unknown destination" do
    start_server

    assert_raises(Imap::MessageMover::FolderNotFound) { Imap::MessageMover.call(build_message, to: "Nowhere") }
  end

  test "raises MessageGone when the UIDVALIDITY has changed" do
    start_server

    assert_raises(Imap::MessageMover::MessageGone) { Imap::MessageMover.call(build_message(uidvalidity: 999), to: "Archive") }
  end

  test "raises MessageGone when the uid is no longer on the server" do
    start_server

    assert_raises(Imap::MessageMover::MessageGone) { Imap::MessageMover.call(build_message(uid: 404), to: "Archive") }
  end

  test "raises MessageGone when the source folder is gone" do
    start_server
    @mailboxes.delete("INBOX")

    assert_raises(Imap::MessageMover::MessageGone) { Imap::MessageMover.call(build_message, to: "Archive") }
  end

  test "trash moves to the Trash folder found by special-use" do
    start_server

    result = Imap::MessageMover.trash(build_message)

    assert_equal "Trash", result.folder
    assert_equal 1, @mailboxes["Trash"][:messages].size
  end

  test "trash finds a folder by its usual name, including under a parent" do
    @mailboxes["INBOX/Papierkorb"] = { uidvalidity: 444, messages: [] }
    @mailboxes.delete("Trash")
    start_server
    @server.instance_variable_get(:@folders).replace([ { name: "INBOX" }, { name: "INBOX/Papierkorb" } ])

    assert_equal "INBOX/Papierkorb", Imap::MessageMover.trash(build_message).folder
  end

  test "trash raises FolderNotFound and moves nothing when there is no Trash folder" do
    @mailboxes.delete("Trash")
    start_server
    @server.instance_variable_get(:@folders).reject! { |f| f[:name] == "Trash" }

    assert_raises(Imap::MessageMover::FolderNotFound) { Imap::MessageMover.trash(build_message) }
    assert_equal 2, @mailboxes["INBOX"][:messages].size
  end
end
