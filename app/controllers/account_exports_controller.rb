# frozen_string_literal: true

# Serves an export that was too large to build in the request, for the link mailed to its owner.
# No session cookie is required: the token in the URL is the credential, scoped to one export and
# expiring with it, the same shape as attachment downloads.
class AccountExportsController < ApplicationController
  allow_unauthenticated_access

  def show
    export_file = AccountExportFile.find_ready(params[:token])
    head(:not_found) and return if export_file.nil?

    send_data export_file.payload, filename: AccountExport.filename(export_file.user, now: export_file.created_at),
      type: "application/json", disposition: "attachment"
  end
end
