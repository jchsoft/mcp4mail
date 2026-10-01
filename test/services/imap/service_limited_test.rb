require "test_helper"
require "net/imap"

class Imap::ServiceLimitedTest < ActiveSupport::TestCase
  def build_account(server)
    users(:one).mail_accounts.create!(host: "127.0.0.1", port: server.port, ssl: false, username: "bob", password: "fixture-app-password")
  end

  def inbox
    { "INBOX" => { uidvalidity: 1, messages: [ { uid: 1, body: "Subject: Hi\r\n\r\nHello".b } ] } }
  end

  test "a LOGIN refused for too many simultaneous connections raises ServiceLimited and records it" do
    server = FakeImapServer.new(over_limit: :connections).start
    account = build_account(server)

    error = assert_raises(Imap::ServiceLimited) { Imap::Connection.open(account) { |imap| imap.capability } }

    assert_match "Too many simultaneous connections", error.message
    assert_kind_of Net::IMAP::NoResponseError, error.cause
    assert_match "Too many simultaneous connections", account.reload.last_error
  ensure
    server&.stop
  end

  test "a FETCH refused over the bandwidth limit is ServiceLimited, not a message that is gone" do
    server = FakeImapServer.new(over_limit: :bandwidth, mailboxes: inbox).start
    account = build_account(server)
    folder = account.mail_folders.create!(name: "INBOX", uidvalidity: 1)

    error = assert_raises(Imap::ServiceLimited) do
      Imap::MessageBody.call(mail_account: account, mail_folder: folder, uid: 1, uidvalidity: 1, limit: 100)
    end

    assert_match "bandwidth limits", error.message
  ensure
    server&.stop
  end

  test "a BYE over the bandwidth limit is ServiceLimited" do
    server = FakeImapServer.new(over_limit: :bye, mailboxes: inbox).start
    account = build_account(server)

    assert_raises(Imap::ServiceLimited) do
      Imap::Connection.open(account) do |imap|
        imap.examine("INBOX")
        imap.uid_fetch(1, "BODY.PEEK[]")
      end
    end
  ensure
    server&.stop
  end

  test "a limit ends the whole sync instead of being recorded against each folder" do
    server = FakeImapServer.new(over_limit: :bandwidth, folders: [ { name: "INBOX", attrs: %w[HasNoChildren] } ], mailboxes: inbox).start
    account = build_account(server)

    assert_raises(Imap::ServiceLimited) { Imap::MessageSync.call(account) }
  ensure
    server&.stop
  end

  test "an ordinary refusal is left alone" do
    server = FakeImapServer.new(login_ok: false).start
    account = build_account(server)

    assert_raises(Net::IMAP::NoResponseError) { Imap::Connection.open(account) { |imap| imap.capability } }
  ensure
    server&.stop
  end
end
