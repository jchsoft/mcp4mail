require "test_helper"

class MailAccountSyncJobTest < ActiveJob::TestCase
  test "syncs the account's message index" do
    server = FakeImapServer.new(
      folders: [ { name: "INBOX", attrs: %w[HasNoChildren] } ],
      mailboxes: { "INBOX" => { uidvalidity: 1, messages: [ { uid: 1, envelope: { subject: "Hi" } } ] } }
    ).start
    account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: server.port, ssl: false, username: "bob", password: "x")

    MailAccountSyncJob.perform_now(account)

    assert_equal [ "Hi" ], account.mail_messages.pluck(:subject)
  ensure
    server&.stop
  end

  test "a Gmail usage limit schedules a retry instead of failing the job" do
    server = FakeImapServer.new(over_limit: :connections).start
    account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: server.port, ssl: false, username: "bob", password: "x")

    assert_enqueued_with(job: MailAccountSyncJob, args: [ account ]) do
      MailAccountSyncJob.perform_now(account)
    end
  ensure
    server&.stop
  end

  test "the refresh job enqueues a sync for every account" do
    assert_enqueued_jobs MailAccount.count, only: MailAccountSyncJob do
      MailIndexRefreshJob.perform_now
    end
  end

  test "logs once the limit retries are spent" do
    server = FakeImapServer.new(over_limit: :connections).start
    account = users(:one).mail_accounts.create!(host: "127.0.0.1", port: server.port, ssl: false, username: "bob", password: "x")
    logged = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logged)

    perform_enqueued_jobs(only: MailAccountSyncJob) do
      MailAccountSyncJob.perform_later(account)
    end
    # executions climb until the 4th attempt, which runs the block instead of re-enqueuing
    assert_match(/\[MailAccountSyncJob\] mail_account_id=#{account.id} still limited/, logged.string)
  ensure
    Rails.logger = original if original
    server&.stop
  end
end
