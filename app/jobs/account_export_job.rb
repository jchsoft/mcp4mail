# Builds an export too large to hand back in the request and emails its owner a time-limited
# link. The row was created in the request, so the page could already tell them the mail is
# coming; the job only fills in the payload.
class AccountExportJob < ApplicationJob
  queue_as :default

  def perform(account_export_file, raw_token)
    return if account_export_file.payload.present?

    account_export_file.store!(AccountExport.json(account_export_file.user))
    AccountExportsMailer.ready(account_export_file, raw_token).deliver_later
  end
end
