# frozen_string_literal: true

module McpTools
  # Lets the model answer "did it go out" about a message it handed to send_message.
  class GetOutgoingStatus < ApplicationTool
    tool_name "get_outgoing_status"
    title "Check a sent email's approval"

    description <<~TEXT.squish
      Whether an email prepared with send_message was sent. state is "pending" (waiting for the
      owner to approve), "sent" (with sent_at), "discarded" (the owner said no) or "expired" (not
      approved within 24 hours; nothing was sent).
    TEXT

    input_schema(
      type: "object",
      properties: {
        outgoing_message_id: { type: "integer", description: "outgoing_message_id returned by send_message" }
      },
      required: [ "outgoing_message_id" ],
      additionalProperties: false
    )

    private
      def call
        outgoing = current_user.outgoing_messages.find_by(id: arguments["outgoing_message_id"])
        return Hitch::MCP::Result.error("No outgoing message with that id.") if outgoing.nil?

        @mail_account = outgoing.mail_account
        outgoing.expire_if_due!
        rows_returned!(1)
        json_result(
          outgoing_message_id: outgoing.id, account_id: outgoing.mail_account_id, state: outgoing.state,
          sent_at: outgoing.sent_at&.iso8601, expires_at: outgoing.expires_at.iso8601
        )
      end
  end
end
