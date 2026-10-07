require "test_helper"
require_relative "../../support/fake_autodetect_network"

class Smtp::AutodetectTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  # The lookups and the EHLO + AUTH check stand in for DNS and real servers: the test decides
  # what each source offers and which host:port accepts the login.
  class Scripted < Smtp::Autodetect
    def initialize(mail_account, autoconfig: [], srv: [], accepts: [])
      super(mail_account)
      @autoconfig = autoconfig
      @srv = srv
      @accepts = accepts
    end

    private
      def autoconfig_candidates = @autoconfig
      def srv_candidates = @srv
      def verify(candidate) = @accepts.include?([ candidate.host, candidate.port ])
  end

  setup do
    @account = mail_accounts(:work)
  end

  test "an autoconfig answer that accepts the login wins over guesses" do
    offered = Smtp::Autodetect::Settings.new(host: "out.example.com", port: 587, tls: :starttls)

    found = Scripted.new(@account, autoconfig: [ offered ], accepts: [ [ "out.example.com", 587 ], [ "smtp.example.com", 465 ] ]).call

    assert_equal [ "out.example.com", 587, :starttls ], [ found.host, found.port, found.tls ]
  end

  test "guesses try smtp., mail. and the IMAP host, implicit TLS on 465 before STARTTLS on 587" do
    guesses = Scripted.new(@account).send(:guess_candidates).map { |settings| [ settings.host, settings.port, settings.tls ] }

    assert_equal [
      [ "smtp.example.com", 465, :ssl ], [ "smtp.example.com", 587, :starttls ],
      [ "mail.example.com", 465, :ssl ], [ "mail.example.com", 587, :starttls ],
      [ "imap.example.com", 465, :ssl ], [ "imap.example.com", 587, :starttls ]
    ], guesses
  end

  test "the first guess in preference order wins, not the fastest" do
    found = Scripted.new(@account, accepts: [ [ "mail.example.com", 587 ], [ "smtp.example.com", 587 ] ]).call

    assert_equal [ "smtp.example.com", 587, :starttls ], [ found.host, found.port, found.tls ]
  end

  test "nothing that accepts the login finds nothing" do
    assert_nil Scripted.new(@account).call
  end

  # Net::SMTP stand-in: `accepts` lists the host:port pairs whose login works; everything
  # else raises `failure`, the way a real connection would.
  class FakeSmtp
    cattr_accessor :started, default: []

    def initialize(host, port, accepts:, failure:)
      @host = host
      @port = port
      @accepts = accepts
      @failure = failure
    end

    attr_writer :open_timeout, :read_timeout
    def enable_tls = @tls = true
    def enable_starttls = @starttls = true

    def start(helo:, user:, secret:)
      self.class.started << [ @host, @port, helo, user, secret, @tls ? :ssl : :starttls ]
      raise @failure unless @accepts.include?([ @host, @port ])

      yield
    end
  end

  def with_smtp(accepts: [], failure: Net::SMTPAuthenticationError.new("535 refused"), pages: {}, zone: {}, &block)
    FakeSmtp.started = []
    opener = ->(host, port) { FakeSmtp.new(host, port, accepts:, failure:) }
    autoconfig(pages) { dns(zone) { replace_singleton(Net::SMTP, :new, opener, &block) } }
  end

  def autoconfig_doc(host, port, socket_type: "STARTTLS")
    <<~XML
      <clientConfig version="1.1"><emailProvider id="example.com">
        <outgoingServer type="smtp"><hostname>#{host}</hostname><port>#{port}</port><socketType>#{socket_type}</socketType></outgoingServer>
      </emailProvider></clientConfig>
    XML
  end

  test "the provider's autoconfig document is the first source, confirmed with the account's own login" do
    found = with_smtp(accepts: [ [ "out.example.com", 587 ] ], pages: { "/v1.1/example.com" => autoconfig_doc("out.example.com", 587) }) do
      Smtp::Autodetect.call(@account)
    end

    assert_equal [ "out.example.com", 587, :starttls ], [ found.host, found.port, found.tls ]
    assert_equal [ "out.example.com", 587, "example.com", "one@example.com", "fixture-app-password", :starttls ], FakeSmtp.started.first
  end

  test "SRV records are sorted by priority then weight, and a blank host or port 0 is skipped" do
    zone = { "_submission._tcp.example.com" => { Resolv::DNS::Resource::IN::SRV => [
      srv("low.example.com", 587, priority: 20), srv("light.example.com", 587, priority: 10, weight: 5),
      srv("heavy.example.com", 587, priority: 10, weight: 50), srv("", 587), srv("zero.example.com", 0)
    ] } }

    candidates = with_smtp(zone:) { Smtp::Autodetect.new(@account).send(:srv_candidates) }

    assert_equal [ "heavy.example.com", "light.example.com", "low.example.com" ], candidates.map(&:host)
    assert_equal [ :starttls ], candidates.map(&:tls).uniq
  end

  test "an implicit-TLS SRV record is used when it is the one that accepts the login" do
    zone = { "_submissions._tcp.example.com" => { Resolv::DNS::Resource::IN::SRV => [ srv("tls.example.com", 465) ] } }

    found = with_smtp(accepts: [ [ "tls.example.com", 465 ] ], zone:) { Smtp::Autodetect.call(@account) }

    assert_equal [ "tls.example.com", 465, :ssl ], [ found.host, found.port, found.tls ]
  end

  test "an SRV lookup that fails is logged and the guesses take over" do
    broken = Object.new
    broken.define_singleton_method(:getresources) { |_name, _type| raise Resolv::ResolvError, "no resolver" }
    opener = ->(**_options, &inner) { inner.call(broken) }

    found = with_smtp(accepts: [ [ "smtp.example.com", 587 ] ]) do
      replace_singleton(Resolv::DNS, :open, opener) { Smtp::Autodetect.call(@account) }
    end

    assert_equal [ "smtp.example.com", 587, :starttls ], [ found.host, found.port, found.tls ]
  end

  test "the probe accepts a server that takes the login" do
    found = with_smtp(accepts: [ [ "smtp.example.com", 465 ] ]) { Smtp::Autodetect.call(@account) }

    assert_equal [ "smtp.example.com", 465, :ssl ], [ found.host, found.port, found.tls ]
  end

  test "a server that refuses the login is not a candidate" do
    with_smtp(failure: Net::SMTPAuthenticationError.new("535 refused")) { assert_nil Smtp::Autodetect.call(@account) }
  end

  test "a server that times out is not a candidate" do
    with_smtp(failure: Net::OpenTimeout.new("execution expired")) { assert_nil Smtp::Autodetect.call(@account) }
  end

  test "an address with no domain finds nothing without asking anyone" do
    @account.username = "bare@"

    assert_nil Smtp::Autodetect.call(@account)
  end

  test "running past the budget finds nothing" do
    slow = Class.new(Smtp::Autodetect) do
      private def detect = sleep(1)
    end

    assert_nil slow.new(@account, budget: 0.01).call
  end

  test "the probe reports a refused connection as no server, over a real socket" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    candidate = Smtp::Autodetect::Settings.new(host: "127.0.0.1", port: port, tls: :starttls)

    assert_equal false, Smtp::Autodetect.new(@account).send(:verify, candidate)
  end
end
