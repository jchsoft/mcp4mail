# Syncs the message index of one MailAccount. Safe to retry: the sync resumes from the
# per-folder cursors it committed before failing.
class MailAccountSyncJob < ApplicationJob
  queue_as :default

  # Two syncs of the same account would fetch the same UID ranges twice.
  limits_concurrency to: 1, key: ->(mail_account) { mail_account }, duration: 15.minutes

  discard_on ActiveJob::DeserializationError
  retry_on Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError, IOError,
    wait: :polynomially_longer, attempts: 5

  def perform(mail_account)
    Imap::MessageSync.call(mail_account)
  end
end
