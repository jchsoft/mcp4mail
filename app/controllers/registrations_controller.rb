class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: t("flash.try_again_later") }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: %i[ email_address password password_confirmation ]))

    if @user.save
      start_new_session_for @user
      redirect_to new_mail_account_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end
end
