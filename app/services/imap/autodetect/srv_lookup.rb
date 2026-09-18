require "resolv"

module Imap
  class Autodetect
    # RFC 6186 service records. Cheaper and more reliable than guessing when a domain
    # publishes them, and unlike autoconfig it needs nothing served over HTTP.
    class SrvLookup
      TIMEOUT = 3
      # _imaps_ is implicit TLS on 993; _imap_ is the plaintext port that we only use with
      # STARTTLS, never bare.
      SERVICES = { "_imaps._tcp." => :ssl, "_imap._tcp." => :starttls }.freeze

      def self.call(email:, domain:)
        new(email: email, domain: domain).call
      end

      def initialize(email:, domain:)
        @email = email
        @domain = domain
      end

      def call
        SERVICES.flat_map { |prefix, tls| candidates(prefix, tls) }
      end

      private

      attr_reader :email, :domain

      def candidates(prefix, tls)
        records(prefix).sort_by { |record| [ record.priority, record.weight * -1 ] }.filter_map do |record|
          host = record.target.to_s.chomp(".")
          # RFC 6186 uses a root target to say "this service is not offered here".
          next if host.blank? || record.port.zero?

          Candidate.new(host: host, port: record.port, tls: tls, usernames: usernames)
        end
      end

      def records(prefix)
        Resolv::DNS.open(timeouts: TIMEOUT) do |dns|
          dns.getresources("#{prefix}#{domain}", Resolv::DNS::Resource::IN::SRV)
        end
      rescue StandardError => e
        Rails.logger.info("[Imap::Autodetect] SRV #{prefix}#{domain} failed: #{e.class}")
        []
      end

      def usernames
        [ email, email.split("@").first ].uniq
      end
    end
  end
end
