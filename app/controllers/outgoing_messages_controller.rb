# frozen_string_literal: true

# Send and Discard for the messages waiting under a mailbox on the mailboxes page: the same
# decision as the emailed link, for an owner who is already signed in.
class OutgoingMessagesController < ApplicationController
  before_action :set_outgoing_message

  def approve
    @outgoing_message.approve!(remote_ip: request.remote_ip)
    redirect_to mail_accounts_path, notice: t(".success", recipient: @outgoing_message.first_recipient), status: :see_other
  rescue OutgoingMessage::NotPending
    redirect_to mail_accounts_path, alert: t("outgoing_messages.not_pending"), status: :see_other
  rescue Smtp::Sender::Failed => e
    redirect_to mail_accounts_path, alert: t("outgoing_messages.send_failed", error: e.message), status: :see_other
  end

  def discard
    @outgoing_message.discard!(remote_ip: request.remote_ip)
    redirect_to mail_accounts_path, notice: t(".success"), status: :see_other
  rescue OutgoingMessage::NotPending
    redirect_to mail_accounts_path, alert: t("outgoing_messages.not_pending"), status: :see_other
  end

  private
    def set_outgoing_message
      @outgoing_message = current_user.outgoing_messages.find(params[:id])
    end
end
