require "test_helper"
require_relative "../../../support/fake_autodetect_network"

class Imap::Autodetect::ProberTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  # A client whose misbehaviour is not an IMAP response: login blows up, or logout does.
  class BrokenClient < FakeAutodetectNetwork::FakeImapClient
    def login(username, password)
      raise IOError, "connection reset" if @config[:login_raises]

      super
    end

    def logout = raise(IOError, "already gone")
  end

  def candidate(host = "imap.example.com", port: 993, tls: :ssl)
    Imap::Autodetect::Candidate.new(host: host, port: port, tls: tls, usernames: [ "bob@example.com" ])
  end

  def probe(*candidates, endpoints:)
    imap(endpoints) { Imap::Autodetect::Prober.call(candidates, password: "secret") }
  end

  def probe_with_client(config)
    opener = ->(_host, **_options) { BrokenClient.new(config) }

    replace_singleton(Net::IMAP, :new, opener) { Imap::Autodetect::Prober.call([ candidate ], password: "secret") }
  end

  test "an unreachable candidate is a miss, not a result" do
    assert_nil probe(candidate, endpoints: {})
  end

  test "a failing STARTTLS upgrade is a miss" do
    endpoints = { [ "imap.example.com", 143 ] => { accepts: [ "bob@example.com" ], starttls: false } }

    assert_nil probe(candidate(port: 143, tls: :starttls), endpoints: endpoints)
  end

  test "an error that is not an IMAP response makes the probe a miss" do
    assert_nil probe_with_client(login_raises: true)
  end

  test "a logout that fails does not lose a successful login" do
    result = probe_with_client(accepts: [ "bob@example.com" ])

    assert result.success?
    assert_equal "imap.example.com", result.host
  end

  test "the first successful candidate in order wins over a later one" do
    endpoints = { [ "imap.example.com", 993 ] => { accepts: [ "bob@example.com" ] }, [ "mail.example.com", 993 ] => { accepts: [ "bob@example.com" ] } }

    assert_equal "imap.example.com", probe(candidate, candidate("mail.example.com"), endpoints: endpoints).host
  end

  test "a rejected login outranks a candidate nothing answers on" do
    result = probe(candidate, candidate("mail.example.com"), endpoints: { [ "imap.example.com", 993 ] => { accepts: [] } })

    assert_not result.success?
    assert_equal :auth_failed, result.reason
  end

  test "an IMAP-disabled refusal is told apart from a wrong password" do
    result = probe(candidate, endpoints: { [ "imap.example.com", 993 ] => { accepts: [], refusal: "IMAP access is disabled for this account" } })

    assert_equal :imap_disabled, result.reason
    assert_equal "IMAP access is disabled for this account", result.raw_response
  end

  test "duplicate candidates are probed once" do
    endpoints = { [ "imap.example.com", 993 ] => { accepts: [ "bob@example.com" ] } }

    assert_equal "imap.example.com", probe(candidate, candidate, endpoints: endpoints).host
  end
end
