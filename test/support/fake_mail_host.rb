require "socket"
require_relative "fake_autodetect_network"

# MailHost resolves every mail host before connecting. Tests never ask real DNS: a name resolves to
# one public placeholder address unless the test says otherwise with `resolving`. Include the module
# for the helpers that switch the private-network opt-in off, catch sockets and record reports.
module FakeMailHost
  include FakeAutodetectNetwork

  # Public, routable and not ours: what an ordinary provider's host resolves to here.
  PUBLIC_ADDRESS = "93.184.215.14".freeze

  mattr_accessor :zone, default: {}

  def self.resolve(host)
    zone.fetch(host.to_s.downcase) { [ PUBLIC_ADDRESS ] }
  end

  # Maps hostnames to the addresses they resolve to for the length of the block.
  def resolving(records)
    FakeMailHost.zone = records.transform_values { Array(it) }
    yield
  ensure
    FakeMailHost.zone = {}
  end

  # The test environment opts in to private hosts for its 127.0.0.1 fakes; this is production's default.
  def private_hosts_refused
    Rails.configuration.x.allow_private_mail_hosts = false
    yield
  ensure
    Rails.configuration.x.allow_private_mail_hosts = true
  end

  # Every TCP connect attempt made in the block, refused, as [host, port].
  def opened_sockets(&block)
    [].tap do |sockets|
      refuse = ->(host, port, *_rest, **_options) { sockets << [ host, port ]; raise Errno::ECONNREFUSED }
      replace_singleton(Socket, :tcp, refuse) { replace_singleton(TCPSocket, :open, refuse, &block) }
    end
  end

  # Every ExceptionNotifier report made in the block, as [exception, data].
  def refusal_reports(&block)
    [].tap do |reports|
      replace_singleton(ExceptionNotifier, :notify_exception, ->(error, options = {}) { reports << [ error, options[:data] ]; true }, &block)
    end
  end
end

MailHost.resolver = ->(host) { FakeMailHost.resolve(host) }
