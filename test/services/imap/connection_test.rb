require "test_helper"
require "net/imap"

class Imap::ConnectionTest < ActiveSupport::TestCase
  def build_account(port:, ssl: false, password: "fixture-app-password")
    users(:one).mail_accounts.create!(
      host: "127.0.0.1", port: port, ssl: ssl,
      username: "bob", password: password, display_name: "Fake"
    )
  end

  test "yields a logged-in IMAP client and records last_connected_at" do
    server = FakeImapServer.new.start
    account = build_account(port: server.port)

    yielded = nil
    result = Imap::Connection.open(account) { |imap| yielded = imap }

    assert_kind_of Net::IMAP, yielded
    assert_equal yielded, result
    assert account.reload.last_connected_at.present?
    assert_nil account.last_error
  ensure
    server&.stop
  end

  test "closes the connection even when the block raises" do
    server = FakeImapServer.new.start
    account = build_account(port: server.port)

    assert_raises(RuntimeError) do
      Imap::Connection.open(account) { |_imap| raise "boom" }
    end

    assert_equal "boom", account.reload.last_error
  ensure
    server&.stop
  end

  test "records the login failure as last_error without touching last_connected_at" do
    server = FakeImapServer.new(login_ok: false).start
    account = build_account(port: server.port)

    assert_raises(Net::IMAP::NoResponseError) do
      Imap::Connection.open(account) { |imap| imap }
    end

    account.reload
    assert_nil account.last_connected_at
    assert_match(/LOGIN failed/, account.last_error)
  ensure
    server&.stop
  end

  test "raises Errno::ECONNREFUSED for an unreachable host and records last_error" do
    server = FakeImapServer.new.start
    port = server.port
    server.stop

    account = build_account(port: port)

    assert_raises(Errno::ECONNREFUSED) do
      Imap::Connection.open(account) { |imap| imap }
    end

    assert account.reload.last_error.present?
  end

  test "raises an SSL error when TLS is requested against a plaintext endpoint" do
    server = FakeImapServer.tls_trap
    account = build_account(port: server.port, ssl: true)

    assert_raises(OpenSSL::SSL::SSLError) do
      Imap::Connection.open(account) { |imap| imap }
    end
  ensure
    server&.stop
  end
end
