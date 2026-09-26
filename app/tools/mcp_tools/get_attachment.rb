# frozen_string_literal: true

module McpTools
  # One attachment of a message, as a download URL by default or, with inline: true, as its
  # base64 bytes in the result itself.
  #
  # The URL mode never touches IMAP - it only reads the metadata search_messages/get_message
  # already indexed and hands back a signed, short-lived AttachmentDownloadToken URL that
  # re-fetches the attachment when visited. The inline mode fetches the attachment over IMAP
  # right away, for clients whose network cannot reach this server outside the MCP connection
  # (sandboxed agents behind a domain allowlist). Its cap is lower, because the whole file
  # lands in the model's context.
  class GetAttachment < ApplicationTool
    MAX_ATTACHMENT_BYTES = 10.megabytes
    MAX_INLINE_BYTES = 5.megabytes

    tool_name "get_attachment"
    title "Download attachment"

    description <<~TEXT.squish
      Get one attachment of a message. Give it the message id (from search_messages or
      get_message) and the attachment's position in that message's attachments list, where 0
      is the first attachment. By default it returns metadata plus a signed download URL good
      for #{AttachmentDownloadToken::EXPIRES_IN.inspect}, up to #{MAX_ATTACHMENT_BYTES / 1.megabyte}MB.
      Pass inline: true to get the file's bytes as content_base64 in this result instead, up to
      #{MAX_INLINE_BYTES / 1.megabyte}MB - use that when you cannot open URLs on this server,
      for example in a sandbox with restricted network access. Only reads mail; it never
      changes the mailbox.
    TEXT

    input_schema(
      type: "object",
      properties: {
        message_id: { type: "integer", description: "The message id from search_messages or get_message." },
        attachment_index: { type: "integer", description: "Position (0-based) in that message's attachments list." },
        inline: {
          type: "boolean",
          description: "true returns the file's bytes as content_base64 instead of a download URL. " \
            "Recommended when your environment cannot reach URLs on this server. Default false."
        }
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
        return Hitch::MCP::Result.error(too_large_message(attachment["size"])) if attachment["size"].to_i > MAX_ATTACHMENT_BYTES

        inline? ? inline_result(message, attachment) : url_result(message, attachment)
      end

      def inline?
        arguments["inline"] == true
      end

      def url_result(message, attachment)
        rows_returned!(1)
        json_result(metadata(message, attachment).merge(url: download_url(message), expires_in_seconds: AttachmentDownloadToken::EXPIRES_IN.to_i))
      end

      # Checked twice: the indexed size refuses without an IMAP round trip, the decoded size
      # catches an index that under-reports.
      def inline_result(message, attachment)
        return Hitch::MCP::Result.error(too_large_inline_message(attachment["size"])) if attachment["size"].to_i > MAX_INLINE_BYTES

        fetched = fetch_attachment(message)
        return Hitch::MCP::Result.error(gone_message) if fetched.nil?
        return Hitch::MCP::Result.error(too_large_inline_message(fetched.body.bytesize)) if fetched.body.bytesize > MAX_INLINE_BYTES

        rows_returned!(1)
        json_result(metadata(message, attachment).merge(
          filename: fetched.filename || attachment["filename"],
          content_type: fetched.content_type.presence || attachment["content_type"],
          size: fetched.body.bytesize,
          content_base64: Base64.strict_encode64(fetched.body)
        ))
      rescue Imap::MessageAttachment::MessageGone
        Hitch::MCP::Result.error(gone_message)
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end

      def metadata(message, attachment)
        {
          message_id: message.id,
          attachment_index: arguments["attachment_index"],
          filename: attachment["filename"],
          content_type: attachment["content_type"],
          size: attachment["size"]
        }
      end

      def fetch_attachment(message)
        Imap::MessageAttachment.call(
          mail_account: message.mail_account, mail_folder: message.mail_folder,
          uid: message.uid, uidvalidity: message.uidvalidity, index: arguments["attachment_index"]
        )
      end

      def download_url(message)
        token = AttachmentDownloadToken.generate(user: current_user, message:, attachment_index: arguments["attachment_index"])
        Rails.application.routes.url_helpers.attachment_download_url(
          token:, **Rails.application.config.action_mailer.default_url_options
        )
      end

      def gone_message
        "This message or attachment is no longer on the server. Run search_messages again to get a fresh id."
      end

      def too_large_message(size)
        "This attachment is #{human_size(size)}; the maximum this tool will hand out a link for is #{human_size(MAX_ATTACHMENT_BYTES)}."
      end

      def too_large_inline_message(size)
        "This attachment is #{human_size(size)}; the maximum this tool returns inline is #{human_size(MAX_INLINE_BYTES)}. " \
          "Call get_attachment again without inline to get a download URL instead."
      end

      def human_size(bytes)
        ActiveSupport::NumberHelper.number_to_human_size(bytes)
      end
  end
end
