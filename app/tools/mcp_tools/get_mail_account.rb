# frozen_string_literal: true

module McpTools
  class GetMailAccount < ApplicationTool
    tool_name "get_mail_account"
    title "Show mailbox"
    description "Show the connection details of one of your mail accounts (never its password). ai_permissions lists what the AI may change in this mailbox; tools outside it are refused. indexed_at is when the mail index was last refreshed (every 15 minutes; mail newer than that is not searchable yet), and sync_errors appears only when a folder failed to sync."
    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" }
      },
      required: [ "account_id" ],
      additionalProperties: false
    )

    private
      def call
        rows_returned!(1)
        json_result(account_summary(mail_account))
      end
  end
end
