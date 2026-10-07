require "test_helper"
require_relative "../../../support/fake_autodetect_network"

class Imap::Autodetect::SrvLookupTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  SRV = Resolv::DNS::Resource::IN::SRV
  IMAPS = "_imaps._tcp.example.com".freeze
  IMAP = "_imap._tcp.example.com".freeze

  def lookup(zone)
    dns(zone) { Imap::Autodetect::SrvLookup.call(email: "bob@example.com", domain: "example.com") }
  end

  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  test "turns records into candidates, implicit TLS for _imaps_ and STARTTLS for _imap_" do
    found = lookup(IMAPS => { SRV => [ srv("imap.example.net", 993) ] }, IMAP => { SRV => [ srv("imap.example.net", 143) ] })

    assert_equal [ [ "imap.example.net", 993, :ssl ], [ "imap.example.net", 143, :starttls ] ], found.map(&:key)
    assert_equal [ "bob@example.com", "bob" ], found.first.usernames
  end

  test "orders by priority, then by higher weight" do
    records = [ srv("late.example.net", 993, priority: 20), srv("light.example.net", 993, weight: 1), srv("heavy.example.net", 993, weight: 9) ]

    assert_equal %w[heavy.example.net light.example.net late.example.net], lookup(IMAPS => { SRV => records }).map(&:host)
  end

  test "skips a root target and a zero port, which mean the service is not offered" do
    assert_empty lookup(IMAPS => { SRV => [ srv("", 993), srv("imap.example.net", 0) ] })
  end

  test "a DNS failure is logged and yields no candidates" do
    resolver = Object.new
    resolver.define_singleton_method(:getresources) { |*| raise Resolv::ResolvTimeout }
    found = nil

    log = capture_log do
      replace_singleton(Resolv::DNS, :open, ->(**_options, &inner) { inner.call(resolver) }) do
        found = Imap::Autodetect::SrvLookup.call(email: "bob@example.com", domain: "example.com")
      end
    end

    assert_empty found
    assert_includes log, "[Imap::Autodetect] SRV #{IMAPS} failed: Resolv::ResolvTimeout"
    assert_includes log, "[Imap::Autodetect] SRV #{IMAP} failed: Resolv::ResolvTimeout"
  end
end
