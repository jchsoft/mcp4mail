require "test_helper"

# The "add mailbox" form was used on 2026-11-18 to make the server connect to its own ports. A host
# inside the network is refused before any socket is opened, reported, and answered with one message.
class MailAccountsInternalHostTest < ActionDispatch::IntegrationTest
  include FakeMailHost

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  def manual_params(host:, port: 993)
    { mail_account: { email_address: "bob@example.com", password: "app-password", host:, port:, tls_mode: "none", username: "bob" } }
  end

  def detection_params(email_address: "bob@evil.example")
    { mail_account: { email_address:, password: "app-password", host: "", port: "993", tls_mode: "ssl", username: "" } }
  end

  # Runs the request with private hosts refused, and returns the sockets it tried and the reports it sent.
  def attempt(params)
    reports = nil
    sockets = opened_sockets do
      reports = refusal_reports do
        private_hosts_refused do
          assert_no_difference -> { MailAccount.count } do
            post mail_accounts_path, params:, headers: { "User-Agent" => "probe/1.0" }
          end
        end
      end
    end
    [ sockets, reports ]
  end

  def assert_refused_for(host, address: host, port: 993)
    sockets, reports = attempt(manual_params(host:, port:))

    assert_response :unprocessable_entity
    assert_select "#connection-error", /This address points inside our network/
    assert_empty sockets
    error, data = reports.sole
    assert_kind_of MailAccount::InternalHostRefused, error
    assert_equal({ user_id: @user.id, host:, address:, port:, remote_ip: "127.0.0.1", user_agent: "probe/1.0" }, data)
    assert_no_enqueued_jobs only: MailAccountSyncJob
  end

  test "refuses 127.0.0.1 without opening a socket and reports it" do
    assert_refused_for "127.0.0.1", port: 6379
  end

  test "refuses ::1" do
    assert_refused_for "::1", port: 5432
  end

  test "refuses a private address" do
    assert_refused_for "10.0.0.5"
  end

  test "refuses the cloud metadata address" do
    assert_refused_for "169.254.169.254", port: 80
  end

  test "refuses a hostname that resolves to 127.0.0.1" do
    resolving("internal.evil.example" => "127.0.0.1") { assert_refused_for "internal.evil.example", address: "127.0.0.1", port: 22 }
  end

  test "answers the same whatever the port" do
    bodies = [ 22, 6379, 11_211 ].map do |port|
      attempt(manual_params(host: "127.0.0.1", port:))
      css_select("#connection-error").sole.text.squish
    end

    assert_equal 1, bodies.uniq.size
  end

  test "refuses an SRV record that points to 127.0.0.1 during detection" do
    zone = { "_imaps._tcp.evil.example" => { Resolv::DNS::Resource::IN::SRV => [ srv("mail.evil.example", 6379) ] } }
    tried = []
    opener = ->(host, port:, **) { tried << [ host, port ]; raise Errno::ECONNREFUSED }
    sockets = reports = nil

    resolving("mail.evil.example" => "127.0.0.1") do
      autoconfig({}) do
        dns(zone) do
          replace_singleton(Net::IMAP, :new, opener) { sockets, reports = attempt(detection_params) }
        end
      end
    end

    assert_response :unprocessable_entity
    assert_select "#connection-error", /This address points inside our network/
    assert_empty sockets
    assert_not_includes tried, [ "mail.evil.example", 6379 ]
    error, data = reports.sole
    assert_equal [ "mail.evil.example", "127.0.0.1", 6379 ], [ error.host, error.address, error.port ]
    assert_equal @user.id, data[:user_id]
  end

  test "a public host is still detected and saved" do
    zone = { "_imaps._tcp.example.org" => { Resolv::DNS::Resource::IN::SRV => [ srv("imap.example.org", 993) ] } }
    endpoints = { [ "imap.example.org", 993 ] => { accepts: [ "bob@example.org" ], password: "app-password" } }

    private_hosts_refused do
      autoconfig({}) do
        dns(zone) do
          imap(endpoints) do
            assert_difference -> { @user.mail_accounts.count } do
              post mail_accounts_path, params: detection_params(email_address: "bob@example.org")
            end
          end
        end
      end
    end

    assert_redirected_to mail_accounts_path
    assert_equal "imap.example.org", @user.mail_accounts.order(:created_at).last.host
  end

  test "with the opt-in a server on 127.0.0.1 still connects" do
    server = FakeImapServer.new.start

    assert_difference -> { @user.mail_accounts.count } do
      post mail_accounts_path, params: manual_params(host: "127.0.0.1", port: server.port)
    end

    assert_redirected_to mail_accounts_path
  ensure
    server&.stop
  end

  test "the refusal is translated into Czech" do
    private_hosts_refused { post mail_accounts_path(locale: :cs), params: manual_params(host: "127.0.0.1") }

    assert_select "#connection-error", /Tato adresa vede do naší vnitřní sítě/
  end
end
