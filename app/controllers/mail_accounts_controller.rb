class MailAccountsController < ApplicationController
  before_action :set_mail_account, only: %i[ activity update destroy ]

  def index
    @mail_accounts = current_user.mail_accounts.order(:created_at)
    @today_counts = audit_events.count_by_account(since: Time.current.beginning_of_day)
    @week_counts = audit_events.count_by_account(since: Time.current.beginning_of_week)
  end

  # The frame under each mailbox, fetched when its disclosure is opened: the index itself
  # stays one page load however many mailboxes are on it.
  def activity
    @events = audit_events.for_account(@mail_account).recent.to_a
    @client_names = McpAuditEvent.client_names_for(@events)
  end

  def new
    @mail_account = current_user.mail_accounts.build
  end

  # Most people only know their address and password, so the server settings are detected
  # from those. Anyone who opened "Connection details" and typed a server in knows better
  # than the detection does, and gets their settings tested as they are. Either way the
  # login is proven before anything is saved.
  def create
    @mail_account = current_user.mail_accounts.build(mail_account_params)
    @mail_account.username = @mail_account.username.presence || @mail_account.email_address
    manual_settings? ? create_with_manual_settings : create_with_detection
  end

  # The list's "Allow the AI to make changes" switch. It is the only thing edited here: the
  # connection settings are proven at create time and not changed afterwards.
  def update
    @mail_account.update!(writable: params.expect(mail_account: [ :writable ]).fetch(:writable))
    key = @mail_account.writable? ? ".writable" : ".read_only"
    redirect_to mail_accounts_path, notice: t(key, name: @mail_account.label), status: :see_other
  end

  def destroy
    @mail_account.destroy
    redirect_to mail_accounts_path, notice: t(".success", name: @mail_account.label), status: :see_other
  end

  private
    def create_with_detection
      return render_form unless detectable?
      result = Imap::Autodetect.call(email: @mail_account.email_address, password: @mail_account.password)
      unless result.success?
        @detection_failure = result.reason
        return render_form
      end
      # Autodetect only reports settings it has just logged in with, so there is nothing left to test.
      @mail_account.assign_attributes(host: result.host, port: result.port, tls_mode: result.tls, username: result.username)
      save_and_sync
    end

    def create_with_manual_settings
      return render_form unless @mail_account.valid?
      result = Imap::ConnectionTester.call(@mail_account)
      unless result.reachable?
        @connection_outcome = result.outcome
        return render_form
      end
      save_and_sync
    end

    def save_and_sync
      @mail_account.last_connected_at = Time.current
      @mail_account.save!
      MailAccountSyncJob.perform_later(@mail_account)
      redirect_to mail_accounts_path, notice: t("mail_accounts.create.success", address: @mail_account.email_address.presence || @mail_account.label)
    end

    def render_form
      @guide = Imap::ConnectionProblem.guide_for(@mail_account.email_address)
      render :new, status: :unprocessable_entity
    end

    def manual_settings?
      @mail_account.host.present?
    end

    # Detection would spend its whole budget on an address without a domain before saying so.
    def detectable?
      unless @mail_account.email_address.to_s.match?(URI::MailTo::EMAIL_REGEXP)
        @mail_account.errors.add(:email_address, @mail_account.email_address.blank? ? :blank : :invalid)
      end
      @mail_account.errors.add(:password, :blank) if @mail_account.password.blank?
      @mail_account.errors.empty?
    end

    def set_mail_account
      @mail_account = current_user.mail_accounts.find(params[:id])
    end

    def audit_events
      current_user.mcp_audit_events
    end

    def mail_account_params
      params.expect(mail_account: %i[ email_address password host port tls_mode username ])
    end
end
