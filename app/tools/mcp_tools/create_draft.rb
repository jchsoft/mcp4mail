# frozen_string_literal: true

module McpTools
  class CreateDraft < ApplicationTool
    tool_name "create_draft"
    title "Save a draft"
    write_tool destructive: false

    description <<~TEXT.squish
      Save a new message or a reply into the Drafts folder. It is not sent: the person opens
      their mail client and sends it themselves. Plain text only, no attachments, up to 100 kB
      and 50 recipients. Give "reply_to_message_id" (an id from search_messages) to thread the
      draft under that message; the subject then gets "Re:" if it has none.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" },
        to: { type: [ "array", "string" ], items: { type: "string" }, description: "Recipient address, or a list of them" },
        cc: { type: [ "array", "string" ], items: { type: "string" }, description: "Optional cc addresses" },
        bcc: { type: [ "array", "string" ], items: { type: "string" }, description: "Optional bcc addresses" },
        subject: { type: "string", description: "Subject line" },
        body: { type: "string", description: "Plain-text body" },
        reply_to_message_id: { type: "integer", description: "Optional message id from search_messages to reply to" }
      },
      required: [ "account_id", "to" ],
      additionalProperties: false
    )

    private
      def call
        original = nil
        if arguments["reply_to_message_id"]
          original = MailMessage.where(mail_account: mail_account).find_by(id: arguments["reply_to_message_id"])
          return Hitch::MCP::Result.error("No message with that id in this mailbox.") if original.nil?
        end

        result = Imap::DraftSaver.call(
          mail_account,
          to: addresses("to"), cc: addresses("cc"), bcc: addresses("bcc"),
          subject: arguments["subject"], body: arguments["body"], reply_to: original
        )
        rows_returned!(1)
        json_result(
          message_id: result.message&.id, folder: result.folder,
          message: "Draft saved to #{result.folder}; open your mail client to send it."
        )
      rescue Imap::DraftSaver::Invalid => e
        Hitch::MCP::Result.error(e.message)
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
        Hitch::MCP::Result.error("The mail server refused to save the draft: #{e.message}")
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end

      # A single string may hold several addresses separated by commas.
      def addresses(key)
        Array(arguments[key]).flat_map { |value| value.to_s.split(",") }.map(&:strip).compact_blank
      end
  end
end
