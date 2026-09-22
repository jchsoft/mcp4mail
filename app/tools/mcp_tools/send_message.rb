# frozen_string_literal: true

module McpTools
  # The one tool that sends mail, and it never does so by itself: it stores the message as an
  # OutgoingMessage and emails the owner a link. The owner's Send is what reaches SMTP.
  class SendMessage < ApplicationTool
    tool_name "send_message"
    title "Send email (after approval)"
    write_tool destructive: true

    WAITING = "Waiting for approval: the owner has to confirm this email before it is sent."

    description <<~TEXT.squish
      Prepare an email to be sent from this mailbox. It is NOT sent right away: the owner gets an
      email with a link and has to press Send within 24 hours, otherwise nothing leaves. Plain
      text only, no attachments, up to 100 kB and #{OutgoingMessage::MAX_RECIPIENTS} recipients,
      at most #{OutgoingMessage::MAX_PENDING_PER_ACCOUNT} messages waiting per mailbox. Give
      "reply_to_message_id" (an id from search_messages) to reply in that thread, or
      "draft_message_id" to send a draft saved earlier; fields you give replace the draft's. Ask
      get_outgoing_status with the returned outgoing_message_id whether it went out.
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
        reply_to_message_id: { type: "integer", description: "Optional message id from search_messages to reply to" },
        draft_message_id: { type: "integer", description: "Optional id of a draft in this mailbox to send" }
      },
      required: [ "account_id" ],
      additionalProperties: false
    )

    private
      def call
        fields = draft_fields
        return fields if fields.is_a?(Hitch::MCP::Result)

        original = nil
        if arguments["reply_to_message_id"]
          original = mailbox_messages.find_by(id: arguments["reply_to_message_id"])
          return Hitch::MCP::Result.error("No message with that id in this mailbox.") if original.nil?
        end

        composer = MessageComposer.new(
          mail_account,
          to: addresses("to") || fields[:to], cc: addresses("cc") || fields[:cc], bcc: addresses("bcc") || [],
          subject: arguments.fetch("subject", fields[:subject]), body: arguments.fetch("body", fields[:body]),
          reply_to: original, in_reply_to: fields[:in_reply_to], max_recipients: OutgoingMessage::MAX_RECIPIENTS
        ).validate!

        outgoing = OutgoingMessage.prepare!(mail_account:, client_id: context.client_id, composer:)
        OutgoingMessagesMailer.approval(outgoing, outgoing.raw_token).deliver_later
        rows_returned!(1)
        json_result(outgoing_message_id: outgoing.id, state: outgoing.state, expires_at: outgoing.expires_at.iso8601, message: WAITING)
      rescue MessageComposer::Invalid, OutgoingMessage::LimitReached => e
        Hitch::MCP::Result.error(e.message)
      rescue Imap::MessageBody::MessageGone
        Hitch::MCP::Result.error("That draft is no longer on the server. Run search_messages again to get a fresh id.")
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end

      # What a saved draft already says, so the model can send it by id alone.
      def draft_fields
        return {} unless arguments["draft_message_id"]

        draft = mailbox_messages.find_by(id: arguments["draft_message_id"])
        return Hitch::MCP::Result.error("No draft with that id in this mailbox.") if draft.nil?

        body = Imap::MessageBody.call(
          mail_account:, mail_folder: draft.mail_folder, uid: draft.uid, uidvalidity: draft.uidvalidity,
          limit: MessageComposer::MAX_BODY_BYTES
        )
        {
          to: draft.to_addresses.pluck("address"), cc: draft.cc_addresses.pluck("address"),
          subject: draft.subject, body: body.text, in_reply_to: draft.in_reply_to
        }
      end

      def mailbox_messages
        MailMessage.where(mail_account:)
      end

      # nil when the model did not give the field, so a draft's value is kept. A single string
      # may hold several addresses separated by commas.
      def addresses(key)
        return nil unless arguments.key?(key)

        Array(arguments[key]).flat_map { |value| value.to_s.split(",") }.map(&:strip).compact_blank
      end
  end
end
