# frozen_string_literal: true

module McpTools
  class ListMailAccounts < ApplicationTool
    tool_name "list_mail_accounts"
    title "List mailboxes"
    description "List the mail accounts you have connected to mcp4mail. Use an account's id with the other tools. ai_permissions lists what the AI may change in this mailbox; tools outside it are refused. indexed_at is when the mail index was last refreshed (every 15 minutes; mail newer than that is not searchable yet), and sync_errors appears only when a folder failed to sync."
    input_schema(
      type: "object",
      properties: {},
      additionalProperties: false
    )

    private
      def call
        accounts = mail_accounts.includes(:mail_folders).order(:id).map { |account| account_summary(account) }
        rows_returned!(accounts.size)
        json_result(accounts)
      end
  end
end
