require "net/http"
require "net/imap"
require "resolv"

# Doubles for the three outside worlds Imap::Autodetect talks to - HTTP for autoconfig, DNS
# for SRV/MX and IMAP itself - so detection can be driven end to end without a network.
# Include the module in a test and describe the world with `autoconfig`, `dns` and `imap`.
# Minitest 6 dropped Object#stub, so the swap is done here.
module FakeAutodetectNetwork
  # An IMAP endpoint with opinions: which usernames it accepts, whether it can upgrade a
  # plaintext connection, and what it says when it turns a login down.
  class FakeImapClient
    def initialize(config)
      @config = config
      @disconnected = false
    end

    def starttls
      raise FakeAutodetectNetwork.response_error("STARTTLS not supported") unless @config[:starttls]
    end

    def login(username, password)
      return true if Array(@config[:accepts]).include?(username) && password == @config.fetch(:password, "secret")

      raise FakeAutodetectNetwork.response_error(@config[:refusal] || "[AUTHENTICATIONFAILED] Invalid credentials")
    end

    def logout = true
    def disconnect = @disconnected = true
    def disconnected? = @disconnected
  end

  def self.response_error(text)
    Net::IMAP::NoResponseError.new(Struct.new(:data).new(Struct.new(:text).new(text)))
  end

  # Maps a request URI to a body; anything not listed answers 404.
  def autoconfig(pages, &block)
    http = Object.new
    http.define_singleton_method(:get) { |path, _headers = nil| pages[path] ? FakeAutodetectNetwork.ok(pages[path]) : FakeAutodetectNetwork.not_found }

    replace_singleton(Net::HTTP, :start, ->(_host, _port, **_options, &inner) { inner.call(http) }, &block)
  end

  # Maps a query name to the records it answers with, per record class.
  def dns(zone, &block)
    resolver = Object.new
    resolver.define_singleton_method(:getresources) { |name, type| Array(zone.dig(name, type)) }

    replace_singleton(Resolv::DNS, :open, ->(**_options, &inner) { inner.call(resolver) }, &block)
  end

  # Maps [host, port] to an endpoint config; anything else refuses the connection.
  def imap(endpoints, &block)
    opener = lambda do |host, port:, **_options|
      config = endpoints[[ host, port ]] or raise Errno::ECONNREFUSED

      FakeImapClient.new(config)
    end

    replace_singleton(Net::IMAP, :new, opener, &block)
  end

  def srv(target, port, priority: 10, weight: 0)
    Resolv::DNS::Resource::IN::SRV.new(priority, weight, port, Resolv::DNS::Name.create("#{target}."))
  end

  def mx(exchange, preference: 10)
    Resolv::DNS::Resource::IN::MX.new(preference, Resolv::DNS::Name.create("#{exchange}."))
  end

  def replace_singleton(owner, name, replacement)
    meta = owner.singleton_class
    original = meta.instance_method(name) if meta.instance_methods(false).include?(name)
    meta.send(:define_method, name, replacement)

    yield
  ensure
    original ? meta.send(:define_method, name, original) : meta.send(:remove_method, name)
  end

  def self.ok(body)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)
    end
  end

  def self.not_found = Net::HTTPNotFound.new("1.1", "404", "Not Found")
end
