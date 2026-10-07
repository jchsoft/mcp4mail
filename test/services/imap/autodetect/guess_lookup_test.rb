require "test_helper"
require_relative "../../../support/fake_autodetect_network"

class Imap::Autodetect::GuessLookupTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  MX = Resolv::DNS::Resource::IN::MX

  def lookup(zone)
    dns(zone) { Imap::Autodetect::GuessLookup.call(email: "bob@example.com", domain: "example.com") }
  end

  def hosts(found)
    found.map(&:host).uniq
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

  test "guesses prefixes and the bare domain, 993 before 143" do
    found = lookup({})

    assert_equal %w[imap.example.com mail.example.com example.com], hosts(found)
    assert_equal [ [ 993, :ssl ], [ 143, :starttls ] ], found.first(2).map { |candidate| [ candidate.port, candidate.tls ] }
    assert_equal [ "bob@example.com", "bob" ], found.first.usernames
  end

  test "mines the MX record for the provider's own imap and mail hosts" do
    found = lookup("example.com" => { MX => [ mx("mx1.example.net") ] })

    assert_equal %w[imap.example.com mail.example.com example.com imap.example.net mail.example.net], hosts(found)
  end

  test "prefixes a single-label exchange too" do
    assert_equal %w[imap.localmx mail.localmx], hosts(lookup("example.com" => { MX => [ mx("localmx") ] })).last(2)
  end

  test "an MX failure is logged and the plain guesses still come back" do
    resolver = Object.new
    resolver.define_singleton_method(:getresources) { |*| raise Resolv::ResolvError }
    found = nil

    log = capture_log do
      replace_singleton(Resolv::DNS, :open, ->(**_options, &inner) { inner.call(resolver) }) do
        found = Imap::Autodetect::GuessLookup.call(email: "bob@example.com", domain: "example.com")
      end
    end

    assert_equal %w[imap.example.com mail.example.com example.com], hosts(found)
    assert_includes log, "[Imap::Autodetect] MX example.com failed: Resolv::ResolvError"
  end
end
