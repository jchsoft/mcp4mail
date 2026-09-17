require "net/imap"
require "timeout"

module Imap
  # Opens an IMAP session for a MailAccount and guarantees it is closed again, even on
  # exception. Every attempt updates the account's last_connected_at / last_error, since
  # that bookkeeping matters no matter which service (folder listing, connection test, ...)
  # triggered the connection.
  class Connection
    # net-imap's own open_timeout only bounds the TCP connect + TLS handshake, not LOGIN
    # or any later command, so a server that stops responding after that would otherwise
    # hang the caller (e.g. a web worker) indefinitely.
    TIMEOUT = 15

    def self.open(mail_account, timeout: TIMEOUT, &block)
      new(mail_account, timeout: timeout).open(&block)
    end

    def initialize(mail_account, timeout: TIMEOUT)
      @mail_account = mail_account
      @timeout = timeout
    end

    def open
      imap = nil

      result = Timeout.timeout(timeout) do
        imap = Net::IMAP.new(
          mail_account.host,
          port: mail_account.port,
          ssl: mail_account.ssl,
          open_timeout: timeout
        )
        imap.login(mail_account.username, mail_account.password)
        log_capabilities(imap)
        yield imap
      end

      record_success
      result
    rescue StandardError => e
      record_failure(e)
      raise
    ensure
      close(imap)
    end

    private

    attr_reader :mail_account, :timeout

    def close(imap)
      return unless imap

      begin
        imap.logout
      rescue StandardError
        nil
      ensure
        imap.disconnect unless imap.disconnected?
      end
    end

    def log_capabilities(imap)
      Rails.logger.info(
        "[Imap::Connection] mail_account_id=#{mail_account.id} host=#{mail_account.host} " \
        "capabilities=#{imap.capability.join(', ')}"
      )
    end

    def record_success
      mail_account.update_columns(last_connected_at: Time.current, last_error: nil)
    end

    def record_failure(error)
      mail_account.update_columns(last_error: error.message)
    end
  end
end
