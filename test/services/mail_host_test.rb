require "test_helper"

class MailHostTest < ActiveSupport::TestCase
  include FakeMailHost

  test "refuses loopback, private, link-local, unspecified, multicast and reserved addresses" do
    private_hosts_refused do
      %w[
        127.0.0.1 127.8.9.10 ::1 10.0.0.5 172.16.0.1 172.31.255.255 192.168.1.1 100.64.0.1 fc00::1 fd12::5
        169.254.169.254 fe80::1 0.0.0.0 :: 224.0.0.1 ff02::1 240.0.0.1 255.255.255.255 192.0.2.1 198.18.0.1 2001:db8::1
        ::ffff:127.0.0.1 ::ffff:10.0.0.5
      ].each { |address| assert MailHost.refused?(address), "#{address} should be refused" }
    end
  end

  test "lets public addresses through" do
    private_hosts_refused do
      %w[ 93.184.215.14 1.1.1.1 172.32.0.1 100.128.0.1 2a00:1450:4001::6d ].each { |address| assert_not MailHost.refused?(address), "#{address} should pass" }
    end
  end

  test "the opt-in allows loopback and private networks, never link-local or reserved ones" do
    %w[ 127.0.0.1 ::1 10.0.0.5 192.168.1.1 fd12::5 ].each { |address| assert_not MailHost.refused?(address), "#{address} should pass with the opt-in" }
    %w[ 169.254.169.254 fe80::1 0.0.0.0 224.0.0.1 ].each { |address| assert MailHost.refused?(address), "#{address} stays refused" }
  end

  test "check! returns the address it checked" do
    resolving("imap.example.net" => "93.184.215.20") do
      assert_equal "93.184.215.20", MailHost.check!("imap.example.net", port: 993)
    end
    assert_equal "::1", MailHost.check!("[::1]", port: 993)
  end

  test "check! refuses a host when any of its addresses is internal" do
    resolving("mixed.example.net" => [ "93.184.215.20", "10.0.0.5" ]) do
      private_hosts_refused do
        error = assert_raises(MailAccount::InternalHostRefused) { MailHost.check!("mixed.example.net", port: 6379) }

        assert_equal [ "mixed.example.net", "10.0.0.5", 6379 ], [ error.host, error.address, error.port ]
      end
    end
  end

  test "check! treats a host that resolves to nothing as unreachable" do
    resolving("nowhere.example.net" => []) do
      assert_raises(SocketError) { MailHost.check!("nowhere.example.net", port: 993) }
    end
  end

  test "imap connects to the checked address and keeps the hostname for TLS" do
    server = FakeImapServer.new.start

    resolving("imap.pinned.example" => "127.0.0.1") do
      imap = MailHost.imap("imap.pinned.example", port: server.port, ssl: false, open_timeout: 3)

      assert_equal "imap.pinned.example", imap.host
      assert_includes imap.capability.map(&:upcase), "IMAP4REV1"
      imap.disconnect
    end
  ensure
    server&.stop
  end

  test "smtp is pinned to the checked address" do
    resolving("smtp.pinned.example" => "93.184.215.30") do
      sockets = opened_sockets do
        assert_raises(Errno::ECONNREFUSED) { MailHost.smtp("smtp.pinned.example", 587).start(helo: "example.com") }
      end

      assert_equal [ [ "93.184.215.30", 587 ] ], sockets
    end
  end

  test "report sends the refusal to the exception notifier with who asked" do
    error = MailAccount::InternalHostRefused.new(host: "127.0.0.1", address: "127.0.0.1", port: 6379)

    reports = refusal_reports { MailHost.report(error, user_id: 7) }

    assert_equal [ [ error, { user_id: 7, host: "127.0.0.1", address: "127.0.0.1", port: 6379, remote_ip: nil, user_agent: nil } ] ], reports
  end
end
