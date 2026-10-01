# Syncs the message index of one MailAccount. Safe to retry: the sync resumes from the
# per-folder cursors it committed before failing.
class MailAccountSyncJob < ApplicationJob
  queue_as :default

  # Two syncs of the same account would fetch the same UID ranges twice.
  limits_concurrency to: 1, key: ->(mail_account) { mail_account }, duration: 15.minutes

  discard_on ActiveJob::DeserializationError
  retry_on Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, IOError,
    wait: :polynomially_longer, attempts: 5
  # Gmail's connection and bandwidth limits clear by themselves, but not within seconds. Once
  # the retries are spent the next MailIndexRefreshJob picks the account up again, so the job
  # ends quietly rather than as a failure.
  retry_on Imap::ServiceLimited, wait: 15.minutes, attempts: 4 do |job, error|
    Rails.logger.warn("[MailAccountSyncJob] mail_account_id=#{job.arguments.first&.id} still limited: #{error.message}")
  end

  def perform(mail_account)
    Imap::MessageSync.call(mail_account)
  end
end
