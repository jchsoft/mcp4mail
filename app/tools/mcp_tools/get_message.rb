# frozen_string_literal: true

module McpTools
  # One message body, fetched from IMAP at call time. Attachment content is never returned -
  # only the metadata already sitting in the index - so a model cannot use this tool to pull
  # binary data through itself.
  class GetMessage < ApplicationTool
    BODY_CHAR_LIMIT = 20_000

    tool_name "get_message"
    description <<~TEXT.squish
      Read one message: its headers and body. Give it the id of a row from search_messages.
      The body prefers plain text; HTML mail is converted to text rather than handed over as
      markup. Attachment names, sizes and content types are listed, never attachment content -
      call get_attachment for that. Very long bodies are cut off at
      #{BODY_CHAR_LIMIT} characters; "truncated": true means there was more.
    TEXT

    input_schema(
      type: "object",
      properties: {
        id: { type: "integer", description: "The message id from a search_messages row." }
      },
      required: [ "id" ],
      additionalProperties: false
    )

    private
      def call
        return Hitch::MCP::Result.error("Give get_message the id of a message from search_messages.") if arguments["id"].blank?

        message = MailMessage.for_user(current_user).find_by(id: arguments["id"])
        return Hitch::MCP::Result.error("No message with that id.") if message.nil?

        body = fetch_body(message)
        rows_returned!(1)
        json_result(response(message, body))
      rescue Imap::MessageBody::MessageGone
        Hitch::MCP::Result.error("This message is no longer on the server. Run search_messages again to get a fresh id.")
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end

      def fetch_body(message)
        Imap::MessageBody.call(
          mail_account: message.mail_account,
          mail_folder: message.mail_folder,
          uid: message.uid,
          uidvalidity: message.uidvalidity,
          limit: BODY_CHAR_LIMIT
        )
      end

      def response(message, body)
        {
          id: message.id,
          account_id: message.mail_account_id,
          folder: message.mail_folder.name,
          date: message.date&.iso8601,
          from: message.from_display,
          to: message.to_addresses.map { |address| MailMessage.display_address(address) },
          cc: message.cc_addresses.map { |address| MailMessage.display_address(address) },
          subject: message.subject,
          body: body.text,
          truncated: body.truncated,
          attachments: message.attachments
        }.tap do |payload|
          payload[:note] = "The body was cut off at #{BODY_CHAR_LIMIT} characters." if body.truncated
        end
      end
  end
end
