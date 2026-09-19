# One row per MCP tool call: who called which tool, for which account, when, how it ended and how
# many rows came back. Arguments are deliberately not stored - a search query is mail content too.
class McpAuditEvent < ApplicationRecord
  OUTCOMES = %w[ok error denied rate_limited search_limited].freeze

  # How many events the activity list shows per mailbox. Long enough to cover a session's
  # worth of calls, short enough to stay a glance rather than a log.
  RECENT_LIMIT = 20

  belongs_to :user
  belongs_to :mail_account, optional: true

  # A call that named no account (list_mail_accounts, a search across every mailbox) belongs
  # to no mailbox either, so it is neither counted nor listed under one.
  scope :for_account, ->(mail_account) { where(mail_account_id: mail_account.id) }
  scope :since, ->(time) { where(created_at: time..) }
  scope :recent, -> { order(created_at: :desc).limit(RECENT_LIMIT) }

  validates :tool_name, presence: true
  validates :client_id, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :rows_returned, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # { mail_account_id => count }, so the mailboxes page asks once for every account
  # rather than once per account.
  def self.count_by_account(since:)
    where(created_at: since..).where.not(mail_account_id: nil).group(:mail_account_id).count
  end

  def self.record!(context:, tool_name:, outcome:, mail_account_id: nil, rows_returned: 0, duration_ms: nil)
    create!(
      user: context.principal,
      mail_account_id:,
      tool_name:,
      outcome:,
      rows_returned:,
      duration_ms:,
      client_id: context.client_id,
      remote_ip: context.remote_ip
    )
  end

  # The outcome a person reads the list for: something asked for their mail and was
  # turned away.
  def denied? = outcome == "denied"

  # What the tool calls itself for people, not the snake_case name on the wire.
  def tool_title = McpToolRegistry.title_for(tool_name)

  # { client_id => client_name } for a whole list in one query. An id whose client row
  # is gone (a registration since deleted) keeps the id as its name - it is still what
  # the caller called itself.
  def self.client_names_for(events)
    Hitch::Client.where(client_id: events.map(&:client_id)).pluck(:client_id, :client_name).to_h
  end
end
