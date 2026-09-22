# The approval request for an email the AI prepared with send_message. It carries the whole
# message, so the owner decides from the preview, and the one link that can send it.
class OutgoingMessagesMailer < ApplicationMailer
  def approval(outgoing_message, raw_token)
    @outgoing_message = outgoing_message
    @mail_account = outgoing_message.mail_account
    @client_name = Hitch::Client.find_by(client_id: outgoing_message.client_id)&.client_name || outgoing_message.client_id
    @url = outgoing_approval_url(raw_token)

    mail subject: t(".subject", subject: outgoing_message.subject.presence || t(".no_subject"), recipient: outgoing_message.first_recipient),
      to: outgoing_message.user.email_address
  end
end
