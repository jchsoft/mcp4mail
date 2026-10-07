require "test_helper"

class Imap::MessageAttachmentTest < ActiveSupport::TestCase
  RAW = <<~RAW.gsub("\n", "\r\n")
    Content-Type: multipart/mixed; boundary="B"

    --B
    Content-Type: text/plain; charset=UTF-8

    See attached
    --B
    Content-Type: text/csv; name="a.csv"
    Content-Disposition: attachment; filename="a.csv"

    x,y
    --B
    Content-Type: application/pdf; name="b.pdf"
    Content-Transfer-Encoding: base64
    Content-Disposition: attachment; filename="b.pdf"

    SGVsbG8=
    --B--
  RAW

  setup do
    @mailboxes = { "INBOX" => { uidvalidity: 111, messages: [ { uid: 1, body: RAW } ] } }
    @server = FakeImapServer.new(mailboxes: @mailboxes).start
    @account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password")
    @folder = @account.mail_folders.create!(name: "INBOX", uidvalidity: 111)
  end

  teardown { @server&.stop }

  def fetch(index: 0, uid: 1, uidvalidity: 111)
    Imap::MessageAttachment.call(mail_account: @account, mail_folder: @folder, uid:, uidvalidity:, index:)
  end

  test "returns the attachment at the depth-first index, decoded" do
    first = fetch(index: 0)
    second = fetch(index: 1)

    assert_equal "a.csv", first.filename
    assert_equal "text/csv", first.content_type
    assert_equal "x,y", first.body.strip
    assert_equal "b.pdf", second.filename
    assert_equal "Hello", second.body
  end

  test "returns nil when the index is past the last attachment" do
    assert_nil fetch(index: 5)
  end

  test "raises MessageGone when the UIDVALIDITY has changed" do
    assert_raises(Imap::MessageAttachment::MessageGone) { fetch(uidvalidity: 999) }
  end

  test "raises MessageGone when the uid is no longer on the server" do
    assert_raises(Imap::MessageAttachment::MessageGone) { fetch(uid: 404) }
  end

  test "raises MessageGone when the folder no longer exists" do
    @mailboxes.delete("INBOX")

    assert_raises(Imap::MessageAttachment::MessageGone) { fetch }
  end
end
