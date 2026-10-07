require "test_helper"

class AccountExportJobTest < ActiveJob::TestCase
  test "stores the export and emails the link" do
    export = AccountExportFile.start!(users(:one))

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      AccountExportJob.perform_now(export, export.raw_token)
    end

    assert_predicate export.reload.payload, :present?
    assert_equal AccountExport.json(users(:one)).class, export.payload.class
  end

  test "does nothing when the payload is already stored" do
    export = AccountExportFile.start!(users(:one))
    export.store!("{}")

    assert_no_enqueued_jobs { AccountExportJob.perform_now(export, export.raw_token) }
    assert_equal "{}", export.reload.payload
  end
end
