# frozen_string_literal: true

# The page behind the link in the approval email. No session cookie is required: the token in
# the URL is the credential, scoped to one message and dead once it is sent, discarded or 24
# hours old, the same shape as attachment downloads. Opening the link shows the message; only
# pressing Send sends it.
class OutgoingApprovalsController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  before_action :set_outgoing_message

  def show
    @outgoing_message.expire_if_due!
  end

  def approve
    @outgoing_message.approve!(remote_ip: request.remote_ip)
    redirect_to outgoing_approval_path(params[:token]), notice: t(".success"), status: :see_other
  rescue OutgoingMessage::NotPending
    redirect_to outgoing_approval_path(params[:token]), status: :see_other
  rescue Smtp::Sender::Failed => e
    redirect_to outgoing_approval_path(params[:token]), alert: t("outgoing_messages.send_failed", error: e.message), status: :see_other
  end

  def discard
    @outgoing_message.discard!(remote_ip: request.remote_ip)
    redirect_to outgoing_approval_path(params[:token]), notice: t(".success"), status: :see_other
  rescue OutgoingMessage::NotPending
    redirect_to outgoing_approval_path(params[:token]), status: :see_other
  end

  private
    def set_outgoing_message
      @outgoing_message = OutgoingMessage.find_by_token(params[:token])
      head :not_found if @outgoing_message.nil?
    end
end
