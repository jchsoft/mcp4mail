# frozen_string_literal: true

module McpTools
  # A download URL for one attachment, never its bytes. The tool itself never touches IMAP -
  # it only reads the metadata search_messages/get_message already indexed and hands back a
  # signed, short-lived AttachmentDownloadToken URL that re-fetches the attachment when visited.
  class GetAttachment < ApplicationTool
    MAX_ATTACHMENT_BYTES = 10.megabytes

    tool_name "get_attachment"
    title "Download attachment"

    description <<~TEXT.squish
      Get a download link for one attachment of a message. Give it the message id (from
      search_messages or get_message) and the attachment's position in that message's
      attachments list, where 0 is the first attachment. Returns metadata plus a signed URL
      good for #{AttachmentDownloadToken::EXPIRES_IN.inspect} - never the file's bytes.
      Attachments larger than #{MAX_ATTACHMENT_BYTES / 1.megabyte}MB are refused.
    TEXT

    input_schema(
      type: "object",
      properties: {
        message_id: { type: "integer", description: "The message id from search_messages or get_message." },
        attachment_index: { type: "integer", description: "Position (0-based) in that message's attachments list." }
      },
      required: %w[message_id attachment_index],
      additionalProperties: false
    )

    private
      def call
        return Hitch::MCP::Result.error("Give get_attachment a message_id and attachment_index.") if arguments["message_id"].blank? || arguments["attachment_index"].nil?
        return Hitch::MCP::Result.error("No attachment at that index.") if arguments["attachment_index"].negative?

        message = MailMessage.for_user(current_user).find_by(id: arguments["message_id"])
        return Hitch::MCP::Result.error("No message with that id.") if message.nil?

        attachment = message.attachments[arguments["attachment_index"]]
        return Hitch::MCP::Result.error("No attachment at that index.") if attachment.nil?
        return Hitch::MCP::Result.error(too_large_message(attachment)) if attachment["size"].to_i > MAX_ATTACHMENT_BYTES

        rows_returned!(1)
        json_result(response(message, attachment))
      end

      def response(message, attachment)
        {
          message_id: message.id,
          attachment_index: arguments["attachment_index"],
          filename: attachment["filename"],
          content_type: attachment["content_type"],
          size: attachment["size"],
          url: download_url(message),
          expires_in_seconds: AttachmentDownloadToken::EXPIRES_IN.to_i
        }
      end

      def download_url(message)
        token = AttachmentDownloadToken.generate(user: current_user, message:, attachment_index: arguments["attachment_index"])
        Rails.application.routes.url_helpers.attachment_download_url(
          token:, **Rails.application.config.action_mailer.default_url_options
        )
      end

      def too_large_message(attachment)
        "This attachment is #{ActiveSupport::NumberHelper.number_to_human_size(attachment['size'])}; " \
          "the maximum this tool will hand out a link for is #{ActiveSupport::NumberHelper.number_to_human_size(MAX_ATTACHMENT_BYTES)}."
      end
  end
end
