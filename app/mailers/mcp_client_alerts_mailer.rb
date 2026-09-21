# The security alert a mailbox owner gets when an AI client they have not seen before reads it.
# There is no setting to turn it off, on purpose.
class McpClientAlertsMailer < ApplicationMailer
  def new_client(sighting)
    @sighting = sighting
    @mail_account = sighting.mail_account
    @url = mail_accounts_url

    mail subject: t(".subject", account: @mail_account.label), to: sighting.user.email_address
  end
end
