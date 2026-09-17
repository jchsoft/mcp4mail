# One row per MCP tool call: who called which tool, for which account, when, how it ended and how
# many rows came back. Arguments are deliberately not stored - a search query is mail content too.
class McpAuditEvent < ApplicationRecord
  OUTCOMES = %w[ok error denied rate_limited search_limited].freeze

  belongs_to :user

  validates :tool_name, presence: true
  validates :client_id, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :rows_returned, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

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
end
