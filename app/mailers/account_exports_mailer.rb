class AccountExportsMailer < ApplicationMailer
  def ready(account_export_file, raw_token)
    @user = account_export_file.user
    @url = account_export_download_url(raw_token)
    @expires_in = AccountExportFile::EXPIRES_IN

    mail subject: "Your mcp4mail data export is ready", to: @user.email_address
  end
end
