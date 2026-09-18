require "test_helper"

class Imap::MessageBodyTest < ActiveSupport::TestCase
  setup do
    @mailboxes = { "INBOX" => { uidvalidity: 111, messages: [] } }
  end

  teardown { @server&.stop }

  def start_server(**options)
    @server = FakeImapServer.new(mailboxes: @mailboxes, **options).start
  end

  def account
    @account ||= users(:one).mail_accounts.create!(
      host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password"
    )
  end

  def folder(uidvalidity: 111)
    account.mail_folders.create!(name: "INBOX", uidvalidity: uidvalidity)
  end

  def fetch(uid:, uidvalidity: 111, limit: 20_000)
    Imap::MessageBody.call(mail_account: account, mail_folder: folder(uidvalidity:), uid:, uidvalidity:, limit:)
  end

  def put_message(uid:, body:)
    @mailboxes["INBOX"][:messages] = [ { uid: uid, body: body } ]
  end

  test "prefers the plain text part of a multipart message" do
    put_message(uid: 1, body: <<~RAW.gsub("\n", "\r\n"))
      Content-Type: multipart/alternative; boundary="B"

      --B
      Content-Type: text/plain; charset=UTF-8

      Plain version
      --B
      Content-Type: text/html; charset=UTF-8

      <p>HTML <b>version</b></p>
      --B--
    RAW
    start_server

    result = fetch(uid: 1)

    assert_equal "Plain version", result.text.strip
    assert_not result.truncated
  end

  test "converts an html-only body to text instead of handing back markup" do
    put_message(uid: 1, body: <<~RAW.gsub("\n", "\r\n"))
      Content-Type: text/html; charset=UTF-8

      <p>Řádek jedna</p><br><p>Řádek dva</p>
    RAW
    start_server

    result = fetch(uid: 1)

    assert_equal "Řádek jedna\n\nŘádek dva", result.text
    assert_not_includes result.text, "<p>"
  end

  test "decodes a correctly declared 8-bit charset" do
    text = "Příliš žluťoučký kůň"
    put_message(uid: 1, body: "Content-Type: text/plain; charset=windows-1250\r\n\r\n".b + text.encode("Windows-1250").b)
    start_server

    assert_equal text, fetch(uid: 1).text.strip
  end

  test "falls back to detection when the declared charset does not match the bytes, without raising" do
    text = "Příliš žluťoučký kůň"
    put_message(uid: 1, body: "Content-Type: text/plain; charset=UTF-8\r\n\r\n".b + text.encode("Windows-1250").b)
    start_server

    assert_equal text, fetch(uid: 1).text.strip
  end

  test "truncates a long body and says so" do
    put_message(uid: 1, body: "Content-Type: text/plain; charset=UTF-8\r\n\r\n" + ("a" * 30))
    start_server

    result = fetch(uid: 1, limit: 10)

    assert_equal "a" * 10, result.text
    assert result.truncated
  end

  test "raises MessageGone when the folder's UIDVALIDITY has changed since indexing" do
    put_message(uid: 1, body: "Content-Type: text/plain; charset=UTF-8\r\n\r\nhi")
    start_server

    assert_raises(Imap::MessageBody::MessageGone) { fetch(uid: 1, uidvalidity: 999) }
  end

  test "raises MessageGone when the uid no longer exists on the server" do
    start_server

    assert_raises(Imap::MessageBody::MessageGone) { fetch(uid: 404) }
  end
end
