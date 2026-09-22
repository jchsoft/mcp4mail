# frozen_string_literal: true

# An email the AI asked to send (send_message) and that waits for its owner to say yes. Nothing
# is sent until a person follows the emailed link, or uses the mailboxes page, and presses Send.
# The link carries a one-time token whose digest is kept here, the same shape as
# AccountExportFile: it stops working once the message is sent, discarded or 24 hours old.
#
# The limits are fixed on purpose: a free hosted service must not become a way to mass-mail.
class OutgoingMessage < ApplicationRecord
  STATES = %w[ pending sent discarded expired ].freeze
  EXPIRES_IN = 24.hours
  MAX_PENDING_PER_ACCOUNT = 10
  MAX_RECIPIENTS = 20

  class NotPending < StandardError; end
  class LimitReached < StandardError; end

  belongs_to :user
  belongs_to :mail_account

  # Mail content at rest, like the account password.
  encrypts :subject, :body

  # Returned once, by prepare!, and never stored: the row keeps only its digest.
  attr_accessor :raw_token

  scope :pending, -> { where(state: "pending") }
  # Pending and still within its 24 hours: what counts against the cap and what the owner can act on.
  scope :awaiting_approval, -> { pending.where(expires_at: Time.current..) }

  validates :state, inclusion: { in: STATES }
  validates :client_id, presence: true

  def self.prepare!(mail_account:, client_id:, composer:)
    if mail_account.outgoing_messages.awaiting_approval.count >= MAX_PENDING_PER_ACCOUNT
      raise LimitReached, "#{MAX_PENDING_PER_ACCOUNT} messages from this mailbox are already waiting for approval. " \
        "Ask the owner to send or discard them first."
    end

    raw_token = SecureRandom.urlsafe_base64(32)
    create!(
      user: mail_account.user, mail_account:, client_id:,
      to_addresses: composer.to, cc_addresses: composer.cc, bcc_addresses: composer.bcc,
      subject: composer.subject, body: composer.body, in_reply_to: composer.in_reply_to,
      token_digest: digest(raw_token), expires_at: EXPIRES_IN.from_now
    ).tap { |message| message.raw_token = raw_token }
  end

  # The message behind a link someone followed, in whatever state it is now, or nil.
  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    find_by(token_digest: digest(raw_token))
  end

  def self.digest(raw_token) = Digest::SHA256.hexdigest(raw_token)

  STATES.each do |value|
    define_method(:"#{value}?") { state == value }
  end

  def awaiting_approval?
    pending? && expires_at.future?
  end

  # A pending message past its 24 hours becomes expired the first time anyone looks at it.
  def expire_if_due!
    update!(state: "expired") if pending? && !expires_at.future?
    self
  end

  def recipients
    to_addresses + cc_addresses + bcc_addresses
  end

  def first_recipient
    to_addresses.first
  end

  # The row lock makes a double click, or the link and the mailboxes page at once, send once.
  def approve!(remote_ip: nil)
    expire_if_due!
    with_lock do
      raise NotPending unless awaiting_approval?

      Smtp::Sender.call(mail_account, composer.mail)
      update!(state: "sent", sent_at: Time.current)
    end
    audit!("sent", remote_ip)
  end

  def discard!(remote_ip: nil)
    expire_if_due!
    with_lock do
      raise NotPending unless awaiting_approval?

      update!(state: "discarded")
    end
    audit!("discarded", remote_ip)
  end

  private
    def composer
      MessageComposer.new(mail_account, to: to_addresses, cc: cc_addresses, bcc: bcc_addresses,
        subject:, body:, in_reply_to:, max_recipients: MAX_RECIPIENTS)
    end

    # The owner's answer goes into the same activity list as the tool call that asked for it,
    # credited to the client that asked.
    def audit!(outcome, remote_ip)
      McpAuditEvent.create!(user:, mail_account:, tool_name: "send_message", outcome:, client_id:, remote_ip:)
    end
end
