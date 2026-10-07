require "test_helper"
require_relative "../../../support/fake_autodetect_network"

class Imap::Autodetect::AutoconfigLookupTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  ISPDB = "/v1.1/example.com".freeze
  PROVIDER_DOC = "/mail/config-v1.1.xml?emailaddress=bob%40example.com".freeze
  SERVER_TAGS = { imap: %w[incomingServer imap], smtp: %w[outgoingServer smtp] }.freeze

  def config(host: "imap.example.com", port: 993, socket_type: "SSL", protocol: :imap)
    tag, type = SERVER_TAGS.fetch(protocol)

    <<~XML
      <clientConfig version="1.1"><emailProvider id="example.com">
        <#{tag} type="#{type}"><hostname>#{host}</hostname><port>#{port}</port><socketType>#{socket_type}</socketType><username>%EMAILADDRESS%</username></#{tag}>
      </emailProvider></clientConfig>
    XML
  end

  def lookup(protocol: :imap)
    Imap::Autodetect::AutoconfigLookup.call(email: "bob@example.com", domain: "example.com", protocol: protocol)
  end

  def tls_for(socket_type, port, protocol: :imap)
    autoconfig(ISPDB => config(port: port, socket_type: socket_type, protocol: protocol)) { lookup(protocol: protocol) }.first.tls
  end

  # Answers each request path with a ready-made response, or raises when the value is an exception class.
  def serve(responses, &block)
    http = Object.new
    http.define_singleton_method(:get) do |path, _headers = nil|
      response = responses.fetch(path)
      response.is_a?(Class) ? raise(response) : response
    end

    replace_singleton(Net::HTTP, :start, ->(_host, _port, **_options, &inner) { inner.call(http) }, &block)
  end

  def redirect(location)
    Net::HTTPFound.new("1.1", "302", "Found").tap { |response| response["location"] = location }
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

  test "follows a redirect to the document" do
    found = serve(ISPDB => redirect("/moved.xml"), "/moved.xml" => FakeAutodetectNetwork.ok(config(host: "moved.example.com"))) { lookup }

    assert_equal [ "moved.example.com" ], found.map(&:host)
  end

  test "gives up after the allowed number of redirects" do
    responses = { ISPDB => redirect("/a.xml"), "/a.xml" => redirect("/b.xml"), "/b.xml" => redirect("/c.xml"), "/c.xml" => FakeAutodetectNetwork.ok(config), PROVIDER_DOC => FakeAutodetectNetwork.not_found }

    assert_empty serve(responses) { lookup }
  end

  test "a network failure is logged and treated as no answer" do
    found = nil

    log = capture_log { found = serve(ISPDB => Errno::ECONNREFUSED, PROVIDER_DOC => Net::ReadTimeout) { lookup } }

    assert_empty found
    assert_includes log, "[Imap::Autodetect] autoconfig https://autoconfig.thunderbird.net/v1.1/example.com failed: Errno::ECONNREFUSED"
    assert_includes log, "[Imap::Autodetect] autoconfig https://autoconfig.example.com/mail/config-v1.1.xml?emailaddress=bob%40example.com failed: Net::ReadTimeout"
  end

  test "a document that cannot be read for the protocol yields nothing instead of raising" do
    assert_empty autoconfig(ISPDB => config) { lookup(protocol: :pop3) }
  end

  test "a blank body and a 404 yield nothing" do
    assert_empty autoconfig(ISPDB => " ") { lookup }
    assert_empty autoconfig({}) { lookup }
  end

  test "an entry without host or port is skipped" do
    assert_empty autoconfig(ISPDB => config(host: "")) { lookup }
    assert_empty autoconfig(ISPDB => config(port: 0)) { lookup }
  end

  test "an unnamed socket type is decided by the port for IMAP" do
    assert_equal :ssl, tls_for("plain", 993)
    assert_equal :starttls, tls_for("plain", 143)
  end

  test "an unnamed socket type is decided by the port for SMTP" do
    assert_equal :ssl, tls_for("plain", 465, protocol: :smtp)
    assert_equal :starttls, tls_for("plain", 587, protocol: :smtp)
  end

  test "an explicit socket type wins over the port, in any case" do
    assert_equal :starttls, tls_for("starttls", 993)
    assert_equal :ssl, tls_for("ssl", 143)
  end
end
