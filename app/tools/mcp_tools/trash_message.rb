# frozen_string_literal: true

module McpTools
  class TrashMessage < ApplicationTool
    tool_name "trash_message"
    title "Move to Trash"
    write_tool destructive: true
    annotations(**annotations, idempotent_hint: true)

    description <<~TEXT.squish
      Delete a message the way a mail client does: move it to the Trash folder, where it can
      still be recovered. Nothing is ever permanently deleted or expunged. Give the message id
      from search_messages. The message gets a new id in Trash. A message already in Trash is
      left as it is.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" },
        message_id: { type: "integer", description: "The message id from a search_messages row." }
      },
      required: [ "account_id", "message_id" ],
      additionalProperties: false
    )

    private
      def call
        message = MailMessage.where(mail_account: mail_account).find_by(id: arguments["message_id"])
        return Hitch::MCP::Result.error("No message with that id in this mailbox.") if message.nil?

        result = Imap::MessageMover.trash(message)
        rows_returned!(1)
        json_result(trashed: true, folder: Net::IMAP.decode_utf7(result.folder), path: result.folder)
      rescue Imap::MessageMover::FolderNotFound, Imap::MessageMover::CannotMoveSafely => e
        Hitch::MCP::Result.error(e.message)
      rescue Imap::MessageMover::MessageGone
        Hitch::MCP::Result.error("This message is no longer on the server. Run search_messages again to get a fresh id.")
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
        Hitch::MCP::Result.error("The mail server refused the move to Trash: #{e.message}")
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end
  end
end
