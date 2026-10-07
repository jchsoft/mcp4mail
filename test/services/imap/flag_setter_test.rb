require "test_helper"
require "net/imap"

class Imap::FlagSetterTest < ActiveSupport::TestCase
  setup do
    @mailboxes = { "INBOX" => { uidvalidity: 111, messages: [ { uid: 1, flags: [ "\\Seen" ] } ] } }
  end

  teardown { @server&.stop }

  def start_server(**options)
    @server = FakeImapServer.new(mailboxes: @mailboxes, **options).start
    @account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable: true)
    @folder = @account.mail_folders.create!(name: "INBOX", uidvalidity: 111)
  end

  def build_message(uid: 1, uidvalidity: 111, flags: [ "Seen" ])
    @account.mail_messages.create!(mail_folder: @folder, uid:, uidvalidity:, flags:)
  end

  test "sets and clears flags on the server and mirrors them in the index" do
    start_server
    row = build_message

    flags = Imap::FlagSetter.call(row, flagged: true, seen: false)

    assert_equal [ "Flagged" ], flags
    assert_equal [ "Flagged" ], row.reload.flags
    assert_equal [ "\\Flagged" ], @mailboxes["INBOX"][:messages].first[:flags]
  end

  test "setting a flag that is already set keeps it once" do
    start_server

    assert_equal [ "Seen" ], Imap::FlagSetter.call(build_message, seen: true)
  end

  test "a refused STORE raises and leaves the index untouched" do
    start_server(refuse_store: true)
    row = build_message

    assert_raises(Net::IMAP::NoResponseError) { Imap::FlagSetter.call(row, flagged: true) }
    assert_equal [ "Seen" ], row.reload.flags
  end

  test "raises MessageGone when the UIDVALIDITY has changed" do
    start_server

    assert_raises(Imap::FlagSetter::MessageGone) { Imap::FlagSetter.call(build_message(uidvalidity: 999), flagged: true) }
  end

  test "raises MessageGone when the uid is no longer on the server" do
    start_server

    assert_raises(Imap::FlagSetter::MessageGone) { Imap::FlagSetter.call(build_message(uid: 404), flagged: true) }
  end
end
