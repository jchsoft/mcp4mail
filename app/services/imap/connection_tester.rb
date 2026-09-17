module Imap
  # "Test connection" action for a MailAccount, usable from a controller and from the
  # console alike. Users reliably confuse "wrong password" with "can't reach the server"
  # with "certificate problem", so this reports them as three distinct outcomes instead of
  # a single pass/fail.
  class ConnectionTester
    Result = Struct.new(:outcome, :error_message, :capabilities, keyword_init: true) do
      def reachable?
        outcome == :reachable
      end
    end

    def self.call(mail_account)
      new(mail_account).call
    end

    def initialize(mail_account)
      @mail_account = mail_account
    end

    def call
      capabilities = Connection.open(mail_account) { |imap| imap.capability }
      Result.new(outcome: :reachable, capabilities: capabilities)
    rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
      Result.new(outcome: :auth_failed, error_message: e.message)
    rescue OpenSSL::SSL::SSLError => e
      Result.new(outcome: :tls_problem, error_message: e.message)
    rescue StandardError => e
      Result.new(outcome: :unreachable, error_message: e.message)
    end

    private

    attr_reader :mail_account
  end
end
