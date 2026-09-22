require "net/smtp"
require "resolv"
require "timeout"

module Smtp
  # Finds where an already connected mailbox sends from, the first time it has to send. The
  # sources are the ones Imap::Autodetect uses for the incoming side - the autoconfig document,
  # RFC 6186 SRV records, then hostname guesses - and every candidate is confirmed with EHLO
  # and AUTH using the mailbox's own login, so what gets stored is a server that took it.
  #
  #   Smtp::Autodetect.call(mail_account)
  #   #=> #<Settings host="smtp.example.com" port=465 tls=:ssl> or nil
  class Autodetect
    BUDGET = 15
    CONNECT_TIMEOUT = 3
    PROBE_TIMEOUT = 8
    # _submissions_ is implicit TLS (RFC 8314), _submission_ the port upgraded with STARTTLS.
    SRV_SERVICES = { "_submissions._tcp." => :ssl, "_submission._tcp." => :starttls }.freeze
    PREFIXES = %w[smtp mail].freeze
    # 465 first: implicit TLS is the one we would rather end up on.
    PORTS = { 465 => :ssl, 587 => :starttls }.freeze

    Settings = Struct.new(:host, :port, :tls, keyword_init: true)

    def self.call(mail_account, budget: BUDGET)
      new(mail_account, budget:).call
    end

    def initialize(mail_account, budget: BUDGET)
      @mail_account = mail_account
      @budget = budget
    end

    def call
      return nil if domain.blank?

      Timeout.timeout(budget) { detect }
    rescue Timeout::Error
      nil
    end

    private
      attr_reader :mail_account, :budget

      # Ordered: an answer from the provider itself beats one we inferred. Each source is only
      # asked when the one before it found nothing that works.
      def detect
        [ -> { autoconfig_candidates }, -> { srv_candidates }, -> { guess_candidates } ].each do |source|
          found = probe(source.call)
          return found if found
        end
        nil
      end

      def autoconfig_candidates
        Imap::Autodetect::AutoconfigLookup.call(email: email, domain: domain, protocol: :smtp)
          .map { |candidate| Settings.new(host: candidate.host, port: candidate.port, tls: candidate.tls) }
      end

      def srv_candidates
        SRV_SERVICES.flat_map do |prefix, tls|
          srv_records("#{prefix}#{domain}").sort_by { |record| [ record.priority, -record.weight ] }.filter_map do |record|
            host = record.target.to_s.chomp(".")
            Settings.new(host: host, port: record.port, tls: tls) unless host.blank? || record.port.zero?
          end
        end
      end

      def guess_candidates
        imap_host = mail_account.host
        hosts = PREFIXES.map { |prefix| "#{prefix}.#{domain}" } + [ imap_host.sub(/\Aimap\./, "smtp."), imap_host ]
        hosts.uniq.flat_map { |host| PORTS.map { |port, tls| Settings.new(host:, port:, tls:) } }
      end

      # Tried in parallel, since most guesses are hostnames that never answer, but the winner
      # is the first in preference order.
      def probe(candidates)
        candidates = candidates.uniq { |candidate| [ candidate.host, candidate.port ] }
        return nil if candidates.empty?

        candidates.map { |candidate| Thread.new { candidate if verify(candidate) } }.map(&:value).compact.first
      end

      def verify(candidate)
        Timeout.timeout(PROBE_TIMEOUT) do
          smtp = Net::SMTP.new(candidate.host, candidate.port)
          smtp.open_timeout = CONNECT_TIMEOUT
          smtp.read_timeout = CONNECT_TIMEOUT
          candidate.tls == :ssl ? smtp.enable_tls : smtp.enable_starttls
          smtp.start(helo: domain, user: mail_account.username, secret: mail_account.password) { true }
        end
      rescue StandardError
        false
      end

      def srv_records(name)
        Resolv::DNS.open(timeouts: CONNECT_TIMEOUT) { |dns| dns.getresources(name, Resolv::DNS::Resource::IN::SRV) }
      rescue StandardError => e
        Rails.logger.info("[Smtp::Autodetect] SRV #{name} failed: #{e.class}")
        []
      end

      def email
        mail_account.sender_address
      end

      def domain
        @domain ||= email.split("@").last.to_s.downcase.presence
      end
  end
end
