# frozen_string_literal: true

# The credential behind an attachment download URL: a signed, short-lived pointer to one
# user's one attachment on one message. It carries no attachment bytes - only enough (user,
# message, position in that message's attachments list) to re-derive the attachment over IMAP
# when the URL is visited, which is what keeps get_attachment from ever streaming a file
# through the model.
class AttachmentDownloadToken
  EXPIRES_IN = 5.minutes
  PURPOSE = :attachment_download

  Payload = Struct.new(:user_id, :message_id, :attachment_index, keyword_init: true)

  def self.generate(user:, message:, attachment_index:)
    verifier.generate(
      { "user_id" => user.id, "message_id" => message.id, "attachment_index" => attachment_index },
      expires_in: EXPIRES_IN, purpose: PURPOSE
    )
  end

  def self.verify(token)
    data = verifier.verify(token, purpose: PURPOSE)
    Payload.new(user_id: data["user_id"], message_id: data["message_id"], attachment_index: data["attachment_index"])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
end
