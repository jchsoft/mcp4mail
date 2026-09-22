require "net/smtp"

module Smtp
  # Sends one approved message over the mailbox's own outgoing server and files a copy in its
  # Sent folder, the way a mail client would. The outgoing server is detected on the first send
  # (Smtp::Autodetect) and stored on the account. Only OutgoingMessage#send! calls this: nothing
  # reaches it without a person having confirmed the message.
  class Sender
    SENT_NAMES = [ "sent", "sent items", "sent messages", "odeslané", "odeslaná pošta", "gesendet", "envoyés" ].freeze
    DEFAULT_SENT_FOLDER = "Sent"
    TIMEOUT = 15

    class Failed < StandardError; end

    # Tests deliver through Mail's :test method instead of a socket, the same seam as
    # McpQuota.store_override.
    class_attribute :delivery_override

    def self.call(mail_account, mail)
      new(mail_account).call(mail)
    end

    def initialize(mail_account)
      @mail_account = mail_account
    end

    def call(mail)
      detect! unless mail_account.smtp_host.present?
      deliver(mail)
      file_in_sent(mail)
      mail
    end

    private
      attr_reader :mail_account

      def detect!
        settings = Autodetect.call(mail_account)
        raise Failed, "no outgoing mail server found for #{mail_account.sender_address}" if settings.nil?

        mail_account.update_columns(smtp_host: settings.host, smtp_port: settings.port, smtp_tls: settings.tls.to_s)
      end

      def deliver(mail)
        if delivery_override
          mail.delivery_method(delivery_override)
        else
          mail.delivery_method(:smtp, smtp_settings)
        end
        mail.deliver!
      rescue Net::SMTPError, IOError, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        raise Failed, e.message
      end

      def smtp_settings
        {
          address: mail_account.smtp_host, port: mail_account.smtp_port,
          user_name: mail_account.username, password: mail_account.password, authentication: :plain,
          tls: mail_account.smtp_tls == "ssl", enable_starttls: mail_account.smtp_tls == "starttls",
          open_timeout: TIMEOUT, read_timeout: TIMEOUT
        }
      end

      # The message has already left; a Sent folder that refuses the copy is reported, not
      # turned into a failed send.
      def file_in_sent(mail)
        Imap::Connection.open(mail_account) do |imap|
          imap.append(sent_path(imap), mail.to_s, [ :Seen ], mail.date.to_time)
        end
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { mail_account_id: mail_account.id })
      end

      def sent_path(imap)
        folders = Imap::FolderLister.new(mail_account).list(imap).select(&:selectable)
        found = folders.find { |folder| folder.special_use == :sent } ||
          folders.find { |folder| SENT_NAMES.include?(Net::IMAP.decode_utf7(folder.name).downcase) }
        found ? found.name : Imap::FolderCreator.new(mail_account, name: DEFAULT_SENT_FOLDER).create_in(imap).path
      end
  end
end
