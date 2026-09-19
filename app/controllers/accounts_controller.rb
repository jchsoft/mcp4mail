# The signed-in person's own account: what we hold, a button to take it away with them, and a
# button to end it. Both GDPR actions live here so there is one page to point someone at.
class AccountsController < ApplicationController
  def show
    @mail_accounts_count = current_user.mail_accounts.count
    @messages_count = MailMessage.for_user(current_user).count
    @audit_events_count = current_user.mcp_audit_events.count
  end

  # Small exports are built and streamed on the spot; a large header index would leave someone
  # watching a blank tab, so it becomes a job that emails a link instead.
  def export
    return send_export if AccountExport.synchronous?(current_user)

    export_file = AccountExportFile.start!(current_user)
    AccountExportJob.perform_later(export_file, export_file.raw_token)
    redirect_to account_path, notice: t(".queued", email: current_user.email_address)
  end

  # One transaction, no cooling-off period: the OAuth grants go first so a connected client stops
  # working at once, then the user row takes the mailboxes, their stored passwords, the header
  # index, the audit events and the sessions with it.
  def destroy
    user = current_user

    User.transaction do
      revoke_oauth_grants(user)
      user.destroy!
    end

    forget_session
    redirect_to root_path, notice: t(".success"), status: :see_other
  end

  private
    def send_export
      send_data AccountExport.json(current_user), filename: AccountExport.filename(current_user),
        type: "application/json", disposition: "attachment"
    end

    # Deleting the rows is the revocation: an access token whose record is gone resolves to
    # nobody, and there is no reason to keep a spent grant of a deleted account around.
    def revoke_oauth_grants(user)
      Hitch::AccessToken.where(principal_type: "User", principal_id: user.id.to_s).delete_all
      Hitch::DeviceGrant.where(principal_type: "User", principal_id: user.id.to_s).delete_all
    end

    # The session rows went with the user, so only the cookie and Current are left to clear.
    def forget_session
      Current.session = nil
      cookies.delete(:session_id)
    end
end
