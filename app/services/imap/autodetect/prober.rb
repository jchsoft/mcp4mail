require "net/imap"
require "timeout"

module Imap
  class Autodetect
    # Confirms candidates by logging in, which is the only check that actually proves a
    # setting set works. Candidates from one source are tried in parallel - most of them are
    # hostnames that do not resolve, and waiting for those one after another is what would
    # blow the detection budget - but the winner is still the first in preference order, not
    # whichever thread happened to finish first.
    class Prober
      CONNECT_TIMEOUT = 3
      # Bounds a server that completes the handshake and then goes quiet mid-LOGIN.
      PROBE_TIMEOUT = 8
      # Gmail, Outlook and the smaller providers all phrase it differently; these are the
      # shapes that mean "the account is fine, IMAP access just is not switched on".
      IMAP_DISABLED = /imap.{0,40}(disabled|not enabled|turned off|not available)|enable imap|web login required/i

      def self.call(candidates, password:)
        new(candidates, password: password).call
      end

      def initialize(candidates, password:)
        @candidates = candidates.uniq(&:key)
        @password = password
      end

      def call
        outcomes = @candidates.map { |candidate| Thread.new { probe(candidate) } }.map(&:value).compact

        outcomes.find(&:success?) || outcomes.max_by { |result| REASON_PRIORITY.index(result.reason) || -1 }
      end

      private

      attr_reader :password

      # nil means "nothing answering IMAP here", which is not worth reporting on its own.
      def probe(candidate)
        Timeout.timeout(PROBE_TIMEOUT) do
          imap = connect(candidate)
          next if imap.nil?

          begin
            login(imap, candidate)
          ensure
            close(imap)
          end
        end
      rescue StandardError
        nil
      end

      def connect(candidate)
        imap = Net::IMAP.new(candidate.host, port: candidate.port, ssl: candidate.ssl?, open_timeout: CONNECT_TIMEOUT)
        # Plaintext is never an acceptable outcome, so a server that cannot upgrade is a miss.
        imap.starttls if candidate.starttls?
        imap
      rescue StandardError
        close(imap)
        nil
      end

      def login(imap, candidate)
        error = nil

        candidate.usernames.each do |username|
          begin
            imap.login(username, password)
            return Result.new(host: candidate.host, port: candidate.port, tls: candidate.tls, username: username)
          rescue Net::IMAP::ResponseError => e
            error = e
            break if imap.disconnected?
          end
        end

        rejection(error)
      end

      def rejection(error)
        message = error&.message.to_s

        Result.new(reason: message.match?(IMAP_DISABLED) ? :imap_disabled : :auth_failed, raw_response: message.presence)
      end

      def close(imap)
        return if imap.nil? || imap.disconnected?

        begin
          imap.logout
        rescue StandardError
          nil
        ensure
          imap.disconnect unless imap.disconnected?
        end
      end
    end
  end
end
