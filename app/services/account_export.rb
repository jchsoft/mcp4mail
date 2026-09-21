# frozen_string_literal: true

# Everything mcp4mail stores about one person, as a single JSON document: the user row, the
# mailboxes they connected, the AI clients they granted access to, the audit trail of MCP calls,
# which client first used which mailbox from where, and the header index built from their mail.
# Message bodies are not in it because they are never stored.
#
# No password material is ever included - not the account password digest, not the encrypted
# IMAP passwords. MailAccount#serializable_hash drops its own; the user's digest is left out
# by naming the two columns we do export.
class AccountExport
  # Above this many indexed messages the document is big enough that building it in the request
  # would keep someone staring at a blank tab, so the work moves to a job and comes back as an
  # emailed link instead.
  SYNCHRONOUS_MESSAGE_LIMIT = 2_000

  # Derived from the headers for searching; it is the same data in another shape, and leaving it
  # out keeps the export readable.
  MESSAGE_INTERNAL_COLUMNS = %w[ search_text ].freeze

  def initialize(user)
    @user = user
  end

  class << self
    # Tests reach the deferred path without indexing thousands of messages by lowering the
    # limit here, the same seam McpQuota opens for its store.
    attr_accessor :synchronous_message_limit_override
  end

  def self.call(user) = new(user).to_h

  def self.json(user) = JSON.pretty_generate(new(user).to_h)

  def self.synchronous?(user)
    MailMessage.for_user(user).count <= (synchronous_message_limit_override || SYNCHRONOUS_MESSAGE_LIMIT)
  end

  def self.filename(user, now: Time.current)
    "mcp4mail-#{user.email_address.parameterize}-#{now.strftime('%Y%m%d')}.json"
  end

  def to_h
    {
      "exported_at" => Time.current.iso8601,
      "user" => user_hash,
      "mail_accounts" => mail_accounts,
      "oauth_clients" => oauth_clients,
      "mcp_audit_events" => audit_events,
      "mcp_client_sightings" => client_sightings,
      "messages" => messages
    }
  end

  private
    attr_reader :user

    def user_hash
      { "email_address" => user.email_address, "created_at" => user.created_at.iso8601 }
    end

    def mail_accounts
      user.mail_accounts.order(:created_at).map(&:serializable_hash)
    end

    # One entry per authorization the user granted, newest first. The token digests stay behind:
    # they are credentials, and a digest of one is still a fingerprint of it.
    def oauth_clients
      Hitch::AccessToken.where(principal: user).order(created_at: :desc).map do |token|
        {
          "client_id" => token.client_id,
          "client_name" => token.client_name,
          "scopes" => token.scopes,
          "resource_uri" => token.resource_uri,
          "granted_at" => token.created_at.iso8601,
          "expires_at" => token.expires_at&.iso8601,
          "revoked_at" => token.revoked_at&.iso8601
        }
      end
    end

    def client_sightings
      user.mcp_client_sightings.order(:first_seen_at).map(&:serializable_hash)
    end

    def audit_events
      user.mcp_audit_events.order(:created_at).map(&:serializable_hash)
    end

    def messages
      folder_names = MailFolder.where(mail_account_id: user.mail_accounts.select(:id)).pluck(:id, :name).to_h

      MailMessage.for_user(user).order(:mail_account_id, :date).map do |message|
        message.serializable_hash.except(*MESSAGE_INTERNAL_COLUMNS)
          .merge("folder" => folder_names[message.mail_folder_id])
      end
    end
end
