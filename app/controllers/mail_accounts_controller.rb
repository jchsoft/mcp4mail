class MailAccountsController < ApplicationController
  before_action :set_mail_account, only: :destroy

  def index
    @mail_accounts = current_user.mail_accounts.order(:created_at)
  end

  def new
    @mail_account = current_user.mail_accounts.build
  end

  # The connection test runs before the record is saved: a mailbox that cannot be logged
  # into is not worth storing, and the user is still on the form to fix it.
  def create
    @mail_account = current_user.mail_accounts.build(mail_account_params)
    return render(:new, status: :unprocessable_entity) unless @mail_account.valid?

    result = Imap::ConnectionTester.call(@mail_account)
    unless result.reachable?
      @connection_outcome = result.outcome
      return render(:new, status: :unprocessable_entity)
    end

    @mail_account.last_connected_at = Time.current
    @mail_account.save!
    MailAccountSyncJob.perform_later(@mail_account)
    redirect_to mail_accounts_path, notice: t(".success", name: @mail_account.label)
  end

  def destroy
    @mail_account.destroy
    redirect_to mail_accounts_path, notice: t(".success", name: @mail_account.label), status: :see_other
  end

  private
    def set_mail_account
      @mail_account = current_user.mail_accounts.find(params[:id])
    end

    def mail_account_params
      params.expect(mail_account: %i[ display_name host port ssl username password ])
    end
end
