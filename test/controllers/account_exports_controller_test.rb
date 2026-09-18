require "test_helper"

class AccountExportsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "the emailed link serves the export without a session" do
    export_file = AccountExportFile.start!(@user)
    export_file.store!(AccountExport.json(@user))

    get account_export_download_path(export_file.raw_token)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal @user.email_address, response.parsed_body.dig("user", "email_address")
  end

  test "an unknown, expired or still-building export is not found" do
    get account_export_download_path("not-a-token")
    assert_response :not_found

    building = AccountExportFile.start!(@user)
    get account_export_download_path(building.raw_token)
    assert_response :not_found

    expired = AccountExportFile.start!(@user)
    expired.store!("{}")
    expired.update!(expires_at: 1.minute.ago)
    get account_export_download_path(expired.raw_token)
    assert_response :not_found
  end

  test "the raw token is never stored" do
    export_file = AccountExportFile.start!(@user)

    assert_not_equal export_file.raw_token, export_file.token_digest
    assert_equal 0, AccountExportFile.where(token_digest: export_file.raw_token).count
  end

  test "the job fills the export in and mails its owner the link" do
    export_file = AccountExportFile.start!(@user)

    assert_emails 1 do
      perform_enqueued_jobs do
        AccountExportJob.perform_now(export_file, export_file.raw_token)
      end
    end

    assert_equal @user.email_address, ActionMailer::Base.deliveries.last.to.sole
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, export_file.raw_token
    assert export_file.reload.payload.present?
  end

  test "sweep drops exports whose link has expired" do
    live = AccountExportFile.start!(@user)
    expired = AccountExportFile.start!(@user)
    expired.update!(expires_at: 1.minute.ago)

    AccountExportFile.sweep

    assert AccountExportFile.exists?(live.id)
    assert_not AccountExportFile.exists?(expired.id)
  end
end
