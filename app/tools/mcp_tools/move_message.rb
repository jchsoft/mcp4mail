# frozen_string_literal: true

module McpTools
  class MoveMessage < ApplicationTool
    tool_name "move_message"
    title "Move message"
    write_tool destructive: false

    description <<~TEXT.squish
      Move one message to another folder of the same mailbox. Give the message id from
      search_messages and the destination as a folder path or name from list_folders, or a
      special-use name such as Archive. The message gets a new id in its new folder: search
      again before touching it further.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" },
        message_id: { type: "integer", description: "The message id from a search_messages row." },
        folder: { type: "string", description: "Destination folder path, name, or special-use name (Archive, Trash, Junk, Sent, Drafts)" }
      },
      required: [ "account_id", "message_id", "folder" ],
      additionalProperties: false
    )

    private
      def call
        return Hitch::MCP::Result.error("Give move_message a destination folder.") if arguments["folder"].blank?

        message = MailMessage.where(mail_account: mail_account).find_by(id: arguments["message_id"])
        return Hitch::MCP::Result.error("No message with that id in this mailbox.") if message.nil?

        result = Imap::MessageMover.call(message, to: arguments["folder"])
        rows_returned!(1)
        json_result(moved: result.moved, folder: Net::IMAP.decode_utf7(result.folder), path: result.folder)
      rescue Imap::MessageMover::FolderNotFound, Imap::MessageMover::CannotMoveSafely => e
        Hitch::MCP::Result.error(e.message)
      rescue Imap::MessageMover::MessageGone
        Hitch::MCP::Result.error("This message is no longer on the server. Run search_messages again to get a fresh id.")
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
        Hitch::MCP::Result.error("The mail server refused the move: #{e.message}")
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end
  end
end
