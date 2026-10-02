# frozen_string_literal: true

module McpTools
  class ListMailAccounts < ApplicationTool
    tool_name "list_mail_accounts"
    title "List mailboxes"
    description "List the mail accounts you have connected to mcp4mail. Use an account's id with the other tools. ai_permissions lists what the AI may change in this mailbox; tools outside it are refused."
    input_schema(
      type: "object",
      properties: {},
      additionalProperties: false
    )

    private
      def call
        accounts = mail_accounts.order(:id).map { |account| account_summary(account) }
        rows_returned!(accounts.size)
        json_result(accounts)
      end
  end
end
