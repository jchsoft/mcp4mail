# frozen_string_literal: true

module McpTools
  class SetFlags < ApplicationTool
    tool_name "set_flags"
    title "Flag or mark read"
    write_tool destructive: false
    annotations(**annotations, idempotent_hint: true)

    description <<~TEXT.squish
      Flag or unflag a message, and mark it read or unread. Give the message id from
      search_messages and at least one of "flagged" and "seen" (true to set, false to clear).
      Returns the message's flags afterwards.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" },
        message_id: { type: "integer", description: "The message id from a search_messages row." },
        flagged: { type: "boolean", description: "true to flag the message, false to remove the flag" },
        seen: { type: "boolean", description: "true to mark the message read, false to mark it unread" }
      },
      required: [ "account_id", "message_id" ],
      additionalProperties: false
    )

    private
      def call
        changes = arguments.slice("flagged", "seen").compact.transform_keys(&:to_sym)
        return Hitch::MCP::Result.error("Give set_flags flagged or seen (true or false), or both.") if changes.empty?
        return Hitch::MCP::Result.error("flagged and seen must each be true or false.") unless changes.values.all? { |value| value == true || value == false }

        message = MailMessage.where(mail_account: mail_account).find_by(id: arguments["message_id"])
        return Hitch::MCP::Result.error("No message with that id in this mailbox.") if message.nil?

        flags = Imap::FlagSetter.call(message, **changes)
        rows_returned!(1)
        json_result(id: message.id, flags:, flagged: flags.include?("Flagged"), seen: flags.include?("Seen"))
      rescue Imap::FlagSetter::MessageGone
        Hitch::MCP::Result.error("This message is no longer on the server. Run search_messages again to get a fresh id.")
      rescue Net::IMAP::ResponseError
        raise
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end
  end
end
