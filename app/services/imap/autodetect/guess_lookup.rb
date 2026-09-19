require "resolv"

module Imap
  class Autodetect
    # Last resort: the hostnames a mail admin is most likely to have used. The MX record is
    # worth mining because a domain whose mail is handled by mx.example.net very often
    # answers IMAP on imap.example.net, even when nothing about that is published.
    class GuessLookup
      TIMEOUT = 3
      PREFIXES = %w[imap mail].freeze
      # 993 first: implicit TLS is both the common case and the one we would rather end up on.
      PORTS = { 993 => :ssl, 143 => :starttls }.freeze

      def self.call(email:, domain:)
        new(email: email, domain: domain).call
      end

      def initialize(email:, domain:)
        @email = email
        @domain = domain
      end

      def call
        hosts.flat_map { |host| PORTS.map { |port, tls| Candidate.new(host: host, port: port, tls: tls, usernames: usernames) } }
      end

      private

      attr_reader :email, :domain

      def hosts
        (PREFIXES.map { |prefix| "#{prefix}.#{domain}" } + [ domain ] + mx_hosts).uniq
      end

      # "mx1.example.net" -> "imap.example.net", "mail.example.net". A single-label exchange
      # has no parent domain to prefix, so it is used as it stands.
      def mx_hosts
        mx_exchanges.flat_map do |exchange|
          parent = exchange.split(".", 2).last
          parent.blank? ? [ exchange ] : PREFIXES.map { |prefix| "#{prefix}.#{parent}" }
        end
      end

      def mx_exchanges
        Resolv::DNS.open(timeouts: TIMEOUT) { |dns| dns.getresources(domain, Resolv::DNS::Resource::IN::MX) }
          .sort_by(&:preference)
          .map { |record| record.exchange.to_s.chomp(".").downcase }
          .reject(&:blank?)
      rescue StandardError => e
        Rails.logger.info("[Imap::Autodetect] MX #{domain} failed: #{e.class}")
        []
      end

      def usernames
        [ email, email.split("@").first ].uniq
      end
    end
  end
end
