require "test_helper"

class Imap::ConnectionTesterTest < ActiveSupport::TestCase
  def build_account(port:, ssl: false, password: "fixture-app-password")
    users(:one).mail_accounts.create!(
      host: "127.0.0.1", port: port, ssl: ssl,
      username: "bob", password: password, display_name: "Fake"
    )
  end

  test "reports reachable with capabilities on success" do
    server = FakeImapServer.new(capabilities: "IMAP4rev1 SPECIAL-USE").start
    account = build_account(port: server.port)

    result = Imap::ConnectionTester.call(account)

    assert result.reachable?
    assert_equal :reachable, result.outcome
    assert_includes result.capabilities, "SPECIAL-USE"
    assert_nil result.error_message
  ensure
    server&.stop
  end

  test "reports auth_failed on a rejected login" do
    server = FakeImapServer.new(login_ok: false).start
    account = build_account(port: server.port)

    result = Imap::ConnectionTester.call(account)

    assert_equal :auth_failed, result.outcome
    assert_not result.reachable?
    assert result.error_message.present?
  ensure
    server&.stop
  end

  test "reports tls_problem when TLS negotiation fails" do
    server = FakeImapServer.tls_trap
    account = build_account(port: server.port, ssl: true)

    result = Imap::ConnectionTester.call(account)

    assert_equal :tls_problem, result.outcome
  ensure
    server&.stop
  end

  test "reports unreachable when the host refuses the connection" do
    server = FakeImapServer.new.start
    port = server.port
    server.stop

    account = build_account(port: port)

    result = Imap::ConnectionTester.call(account)

    assert_equal :unreachable, result.outcome
  end
end
