# frozen_string_literal: true

# Serves one attachment's bytes for a signed, short-lived AttachmentDownloadToken minted by
# get_attachment. No session cookie is required: the token itself - scoped to one user's one
# attachment and expiring in AttachmentDownloadToken::EXPIRES_IN - is the credential, the same
# shape a future server-to-server integration could use directly.
class AttachmentDownloadsController < ApplicationController
  allow_unauthenticated_access

  def show
    payload = AttachmentDownloadToken.verify(params[:token])
    head(:not_found) and return if payload.nil?

    message = message_for(payload)
    head(:not_found) and return if message.nil?

    attachment_meta = message.attachments[payload.attachment_index]
    head(:not_found) and return if attachment_meta.nil?

    attachment = fetch_attachment(message, payload.attachment_index)
    head(:gone) and return if attachment.nil?

    send_data attachment.body, filename: attachment.filename || attachment_meta["filename"],
      type: attachment.content_type.presence || attachment_meta["content_type"], disposition: "attachment"
  rescue Imap::MessageAttachment::MessageGone
    head :gone
  rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError
    head :service_unavailable
  end

  private
    def message_for(payload)
      user = User.find_by(id: payload.user_id)
      return nil if user.nil?

      MailMessage.for_user(user).find_by(id: payload.message_id)
    end

    def fetch_attachment(message, attachment_index)
      Imap::MessageAttachment.call(
        mail_account: message.mail_account, mail_folder: message.mail_folder,
        uid: message.uid, uidvalidity: message.uidvalidity, index: attachment_index
      )
    end
end
