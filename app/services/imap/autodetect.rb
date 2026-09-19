require "timeout"

module Imap
  # Works out where a mailbox actually lives from nothing but the address the user typed:
  # asks the well-known autoconfig sources first, falls back to DNS, and only then guesses
  # hostnames - and every candidate is confirmed by an actual LOGIN, so what comes back is
  # a setting set we know works rather than a plausible-looking one.
  #
  #   Imap::Autodetect.call(email: "bob@example.com", password: "secret")
  #   #=> #<Result host="imap.example.com" port=993 tls=:ssl username="bob@example.com" source=:autoconfig>
  #
  # On failure the reason distinguishes "we never found a server" from "the server is there
  # but turned us away", because those need completely different advice in the UI. The raw
  # IMAP response is kept for the follow-up task that turns reasons into provider-specific
  # messages.
  class Autodetect
    # Autoconfig and DNS answer in well under a second each; the budget is dominated by the
    # guesses, which wait on hostnames that mostly do not resolve.
    BUDGET = 15

    # A rejected login is a far more useful thing to report than "nothing found", so it wins
    # over any later source that merely fails to turn up a server.
    REASON_PRIORITY = [ :no_server_found, :timeout, :auth_failed, :imap_disabled ].freeze

    Result = Struct.new(:host, :port, :tls, :username, :source, :reason, :raw_response, keyword_init: true) do
      def success?
        host.present?
      end

      def ssl?
        tls == :ssl
      end
    end

    def self.call(email:, password:, budget: BUDGET)
      new(email: email, password: password, budget: budget).call
    end

    def initialize(email:, password:, budget: BUDGET)
      @email = email.to_s.strip
      @password = password
      @budget = budget
    end

    def call
      return Result.new(reason: :no_server_found) if domain.blank?

      Timeout.timeout(budget) { detect }
    rescue Timeout::Error
      Result.new(reason: :timeout)
    end

    private

    attr_reader :email, :password, :budget

    def detect
      failures = []

      lookups.each do |source, lookup|
        result = probe(lookup.call(email: email, domain: domain), source)
        return result if result&.success?

        failures << result if result
      end

      worst(failures) || Result.new(reason: :no_server_found)
    end

    # Ordered: an answer from the provider itself beats one we inferred.
    def lookups
      { autoconfig: AutoconfigLookup, srv: SrvLookup, guess: GuessLookup }
    end

    def probe(candidates, source)
      return if candidates.empty?

      Prober.call(candidates, password: password)&.tap { |result| result.source = source if result.success? }
    end

    def worst(failures)
      failures.max_by { |result| REASON_PRIORITY.index(result.reason) || -1 }
    end

    def domain
      @domain ||= email.split("@").last.to_s.downcase.presence if email.count("@") == 1
    end
  end
end
