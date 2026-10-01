require "test_helper"

class Imap::FakeImapServerGmailTest < ActiveSupport::TestCase
  def with_gmail
    server = FakeImapServer.new(gmail: true, folders: [ { name: "Work", attrs: %w[HasNoChildren] } ], mailboxes: { "Work" => { uidvalidity: 42, messages: [] } }).start
    server.add_gmail_message(labels: %w[INBOX Work], message_id: "<one@example.test>", envelope: { subject: "Hello" })
    imap = Net::IMAP.new("127.0.0.1", port: server.port, ssl: false)
    imap.login("bob", "secret")
    yield server, imap
  ensure
    imap&.disconnect unless imap&.disconnected?
    server&.stop
  end

  test "advertises Gmail extensions and lists the system folders" do
    with_gmail do |_server, imap|
      assert_includes imap.capability, "X-GM-EXT-1"
      assert_includes imap.capability, "XLIST"
      folders = imap.xlist("", "*").to_h { |f| [ f.name, f.attr ] }
      assert_equal %w[INBOX [Gmail]/All\ Mail [Gmail]/Sent\ Mail [Gmail]/Trash [Gmail]/Spam [Gmail]/Important [Gmail]/Starred Work].sort, folders.keys.sort
      assert_includes folders["[Gmail]/All Mail"], :Allmail
      assert_includes folders["[Gmail]/Trash"], :Trash
    end
  end

  test "one message sits in INBOX, its label and All Mail with a shared id" do
    with_gmail do |_server, imap|
      ids = [ "INBOX", "Work", "[Gmail]/All Mail" ].map do |folder|
        imap.examine(folder)
        message = imap.uid_fetch(1, %w[X-GM-MSGID ENVELOPE]).first
        [ message.attr["X-GM-MSGID"], message.attr["ENVELOPE"].message_id ]
      end
      assert_equal 1, ids.uniq.size
      assert_equal "<one@example.test>", ids.first.last
    end
  end

  test "MOVE out of a label removes only the label" do
    with_gmail do |server, imap|
      imap.select("Work")
      imap.uid_move(1, "INBOX")
      assert_empty server.instance_variable_get(:@mailboxes)["Work"][:messages]
      assert_equal 1, server.instance_variable_get(:@mailboxes)["[Gmail]/All Mail"][:messages].size
    end
  end

  test "MOVE to Trash removes the message from every other folder" do
    with_gmail do |server, imap|
      imap.select("INBOX")
      imap.uid_move(1, "[Gmail]/Trash")
      boxes = server.instance_variable_get(:@mailboxes)
      assert_equal 1, boxes["[Gmail]/Trash"][:messages].size
      (boxes.keys - [ "[Gmail]/Trash" ]).each { |name| assert_empty boxes[name][:messages], name }
    end
  end
end
