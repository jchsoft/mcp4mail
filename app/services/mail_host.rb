require "ipaddr"
require "net/imap"
require "net/smtp"
require "resolv"

# The one gate every outgoing mail connection passes: the IMAP session, autodetect's probes, the
# SMTP probes and the send itself. A mailbox's host is whatever a signed-in stranger typed or
# whatever their own DNS answers, so without this the "add mailbox" form opens a socket to any
# port on the server's own network (it was used as a port scanner on 2026-11-18).
#
#   address = MailHost.check!("imap.example.com", port: 993)   #=> "93.184.215.14"
#   MailHost.imap("imap.example.com", port: 993, ssl: true, open_timeout: 15)
#
# The host is resolved once, every address it resolves to is checked, and the socket is opened
# to the checked address: a second lookup could answer differently (DNS rebinding). TLS still
# uses the hostname, for SNI and the certificate check.
module MailHost
  # Self-hosters with Dovecot next to mcp4mail opt in to loopback and private networks.
  ALLOW_PRIVATE_ENV = "MCP4MAIL_ALLOW_PRIVATE_MAIL_HOSTS".freeze
  RESOLVE_TIMEOUT = 3

  # Refused unless the operator opted in.
  PRIVATE = %w[ 127.0.0.0/8 ::1/128 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 fc00::/7 ].map { IPAddr.new(it) }.freeze
  # Never a mail server, whatever the opt-in says: link-local (cloud metadata at 169.254.169.254),
  # unspecified, multicast, broadcast, documentation, benchmarking and other reserved ranges.
  ALWAYS_REFUSED = %w[
    0.0.0.0/8 169.254.0.0/16 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 fe80::/10 ff00::/8 2001:db8::/32 64:ff9b::/96 100::/64
  ].map { IPAddr.new(it) }.freeze

  # Tests resolve through a fake instead of the network, the same seam as Smtp::Sender.delivery_override.
  mattr_accessor :resolver, default: ->(host) { MailHost.dns.getaddresses(host).map(&:to_s) }

  # Opens the socket to the checked address instead of looking the hostname up again.
  module PinnedSocket
    private

    def tcp_socket(_host, port)
      super(@pinned_address, port)
    end
  end

  class IMAP < Net::IMAP
    include PinnedSocket

    def initialize(host, address:, **options)
      @pinned_address = address
      super(host, **options)
    end
  end

  # Mail's SMTP delivery, with the session pinned to a checked address.
  class SmtpDelivery < Mail::SMTP
    private

    def build_smtp_session
      MailHost.pin(super, settings[:address], port: settings[:port])
    end
  end

  class << self
    # The address to connect to; raises MailAccount::InternalHostRefused when any address the
    # host resolves to is inside the network, and SocketError when it resolves to nothing.
    def check!(host, port:)
      addresses = resolve(host)
      raise SocketError, "#{host} does not resolve" if addresses.empty?

      refused = addresses.find { refused?(it) }
      raise MailAccount::InternalHostRefused.new(host:, address: refused, port:) if refused

      addresses.first
    end

    def imap(host, port:, **options)
      IMAP.new(host, address: check!(host, port:), port:, **options)
    end

    def smtp(host, port)
      pin(Net::SMTP.new(host, port), host, port:)
    end

    def pin(session, host, port:)
      session.instance_variable_set(:@pinned_address, check!(host, port:))
      session.extend(PinnedSocket)
    end

    def refused?(address)
      ip = IPAddr.new(address).native
      ALWAYS_REFUSED.any? { it.include?(ip) } || (!allow_private? && PRIVATE.any? { it.include?(ip) })
    end

    def allow_private?
      Rails.configuration.x.allow_private_mail_hosts
    end

    # Reported to the operator with who asked and from where; the person only ever sees the one
    # message, so the refusal tells nothing about what listens on the port.
    def report(error, user_id:, request: nil)
      data = { user_id:, host: error.host, address: error.address, port: error.port, remote_ip: request&.remote_ip, user_agent: request&.user_agent }
      Rails.logger.warn("[MailHost] refused #{data.to_json}")
      ExceptionNotifier.notify_exception(error, data:)
    end

    def dns
      Resolv.new([ Resolv::Hosts.new, Resolv::DNS.new.tap { it.timeouts = RESOLVE_TIMEOUT } ])
    end

    private

    def resolve(host)
      literal = IPAddr.new(host.to_s.delete_prefix("[").delete_suffix("]"))
      [ literal.to_s ]
    rescue IPAddr::Error
      resolver.call(host).uniq
    end
  end
end
