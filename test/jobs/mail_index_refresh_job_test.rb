require "test_helper"

class MailIndexRefreshJobTest < ActiveJob::TestCase
  test "enqueues one sync per mail account" do
    MailIndexRefreshJob.perform_now

    assert_enqueued_jobs MailAccount.count, only: MailAccountSyncJob
    MailAccount.find_each { |account| assert_enqueued_with(job: MailAccountSyncJob, args: [ account ]) }
  end
end
