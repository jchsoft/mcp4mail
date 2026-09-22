require "cgi"
require "net/http"
require "uri"

module Imap
  class Autodetect
    # Thunderbird's autoconfig protocol: the ISPDB, which carries the settings for most of
    # the large providers, and the same document served by the domain itself, which is how a
    # company publishes settings for its own users. Both speak the same XML, so one parser
    # covers them. The same document lists the outgoing server, so Smtp::Autodetect asks it too.
    class AutoconfigLookup
      ISPDB_URL = "https://autoconfig.thunderbird.net/v1.1/".freeze
      TIMEOUT = 3
      # The ISPDB answers straight off, but a domain serving its own document often does it
      # from a redirect, so follow a couple.
      MAX_REDIRECTS = 2
      SERVERS = { imap: "//incomingServer[@type='imap']", smtp: "//outgoingServer[@type='smtp']" }.freeze
      IMPLICIT_TLS_PORTS = { imap: 993, smtp: 465 }.freeze

      def self.call(email:, domain:, protocol: :imap)
        new(email: email, domain: domain, protocol: protocol).call
      end

      def initialize(email:, domain:, protocol: :imap)
        @email = email
        @domain = domain
        @protocol = protocol
      end

      def call
        urls.lazy.filter_map { |url| candidates_from(fetch(url)) }.find(&:any?) || []
      end

      private

      attr_reader :email, :domain, :protocol

      def urls
        [
          "#{ISPDB_URL}#{domain}",
          "https://autoconfig.#{domain}/mail/config-v1.1.xml?emailaddress=#{CGI.escape(email)}"
        ]
      end

      def fetch(url, redirects: MAX_REDIRECTS)
        response = get(URI.parse(url))

        if response.is_a?(Net::HTTPRedirection) && redirects.positive? && response["location"].present?
          return fetch(URI.join(url, response["location"]).to_s, redirects: redirects - 1)
        end

        response.body if response.is_a?(Net::HTTPOK)
      rescue StandardError => e
        Rails.logger.info("[Imap::Autodetect] autoconfig #{url} failed: #{e.class}")
        nil
      end

      def get(uri)
        Net::HTTP.start(
          uri.host, uri.port,
          use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT
        ) { |http| http.get(uri.request_uri, { "User-Agent" => "mcp4mail autoconfig" }) }
      end

      def candidates_from(body)
        return if body.blank?

        Nokogiri::XML(body).xpath(SERVERS.fetch(protocol)).filter_map { |node| candidate(node) }
      rescue StandardError
        nil
      end

      def candidate(node)
        host = text(node, "hostname")
        port = text(node, "port").to_i
        return if host.blank? || port.zero?

        Candidate.new(host: host, port: port, tls: tls_for(text(node, "socketType"), port), usernames: [ username(node) ])
      end

      def tls_for(socket_type, port)
        return :ssl if socket_type.casecmp?("SSL")
        return :starttls if socket_type.casecmp?("STARTTLS")

        port == IMPLICIT_TLS_PORTS.fetch(protocol) ? :ssl : :starttls
      end

      # %EMAILLOCALPART% is how providers that keep bare logins say so; anything else (an
      # unset element included) means the address itself.
      def username(node)
        text(node, "username").casecmp?("%EMAILLOCALPART%") ? email.split("@").first : email
      end

      def text(node, name)
        node.at_xpath(name)&.text.to_s.strip
      end
    end
  end
end
