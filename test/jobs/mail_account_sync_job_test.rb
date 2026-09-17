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

  test "the refresh job enqueues a sync for every account" do
    assert_enqueued_jobs MailAccount.count, only: MailAccountSyncJob do
      MailIndexRefreshJob.perform_now
    end
  end
end
