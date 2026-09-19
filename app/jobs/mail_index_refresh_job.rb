# Enqueues an index sync for every connected mail account.
class MailIndexRefreshJob < ApplicationJob
  queue_as :default

  def perform
    MailAccount.find_each { |mail_account| MailAccountSyncJob.perform_later(mail_account) }
  end
end
