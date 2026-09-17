require "test_helper"

class Imap::FolderListerTest < ActiveSupport::TestCase
  def build_account(port:, password: "fixture-app-password")
    users(:one).mail_accounts.create!(
      host: "127.0.0.1", port: port, ssl: false,
      username: "bob", password: password, display_name: "Fake"
    )
  end

  test "identifies INBOX and SPECIAL-USE folders" do
    server = FakeImapServer.new(
      capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [
        { name: "INBOX", attrs: %w[HasNoChildren] },
        { name: "Sent", attrs: %w[HasNoChildren Sent] },
        { name: "Trash", attrs: %w[HasNoChildren Trash] },
        { name: "Notes", attrs: %w[HasNoChildren] }
      ]
    ).start
    account = build_account(port: server.port)

    folders = Imap::FolderLister.call(account)

    by_name = folders.index_by(&:name)
    assert_equal :inbox, by_name["INBOX"].special_use
    assert_equal :sent, by_name["Sent"].special_use
    assert_equal :trash, by_name["Trash"].special_use
    assert_nil by_name["Notes"].special_use
    assert by_name["Notes"].selectable
  ensure
    server&.stop
  end

  test "falls back to XLIST when SPECIAL-USE is not advertised" do
    server = FakeImapServer.new(
      capabilities: "IMAP4rev1 XLIST",
      use_xlist: true,
      folders: [
        { name: "INBOX", attrs: %w[HasNoChildren] },
        { name: "[Gmail]/All Mail", attrs: %w[HasNoChildren AllMail] },
        { name: "[Gmail]/Spam", attrs: %w[HasNoChildren Spam] }
      ]
    ).start
    account = build_account(port: server.port)

    folders = Imap::FolderLister.call(account)
    by_name = folders.index_by(&:name)

    assert_equal :inbox, by_name["INBOX"].special_use
    assert_equal :all, by_name["[Gmail]/All Mail"].special_use
    assert_equal :junk, by_name["[Gmail]/Spam"].special_use
  ensure
    server&.stop
  end

  test "returns folders with no special use marked as nil when the server advertises neither extension" do
    server = FakeImapServer.new(
      capabilities: "IMAP4rev1",
      folders: [
        { name: "INBOX", attrs: %w[HasNoChildren] },
        { name: "Archive", attrs: %w[HasNoChildren] }
      ]
    ).start
    account = build_account(port: server.port)

    folders = Imap::FolderLister.call(account)
    by_name = folders.index_by(&:name)

    assert_equal :inbox, by_name["INBOX"].special_use
    assert_nil by_name["Archive"].special_use
  ensure
    server&.stop
  end

  test "marks \\Noselect folders as not selectable" do
    server = FakeImapServer.new(
      folders: [
        { name: "INBOX", attrs: %w[HasNoChildren] },
        { name: "[Gmail]", attrs: %w[HasChildren Noselect] }
      ]
    ).start
    account = build_account(port: server.port)

    by_name = Imap::FolderLister.call(account).index_by(&:name)

    assert by_name["INBOX"].selectable
    assert_not by_name["[Gmail]"].selectable
  ensure
    server&.stop
  end
end
