# frozen_string_literal: true

module McpTools
  class GetMailAccount < ApplicationTool
    tool_name "get_mail_account"
    title "Show mailbox"
    description "Show the connection details of one of your mail accounts (never its password)."
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
