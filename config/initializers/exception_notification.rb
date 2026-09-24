# frozen_string_literal: true

# Where unhandled errors and 500s are emailed. Nothing else watches a self-hosted instance's logs,
# so the operator has to hear about them from the app itself; the middleware is installed in
# production only (development has the console, test has the suite).
#
#   EXCEPTION_NOTIFICATION_RECIPIENTS="me@example.org, ops@example.org"   # several addresses
#   EXCEPTION_NOTIFICATION_RECIPIENTS=""                                  # switched off
#
# Delivery goes through the app's own ActionMailer settings (docs/self-hosting.md "Email"), so an
# instance with no SMTP configured sends nothing; a notification that cannot be delivered is
# logged and swallowed by the gem, never raised, so a broken mail setup cannot turn one error into two.
module ExceptionNotificationRecipients
  # The hosted instance's operator: without a variable an instance is better off telling someone
  # than dropping every error into a log nobody reads. Self-hosters set their own address or "".
  DEFAULT = "chmel@jchsoft.cz"

  def self.call(value = ENV["EXCEPTION_NOTIFICATION_RECIPIENTS"])
    return [ DEFAULT ] if value.nil?

    value.split(",").map(&:strip).reject(&:empty?)
  end
end

if Rails.env.production?
  Rails.application.config.middleware.use ExceptionNotification::Rack,
    email: {
      email_prefix: "[mcp4mail] ",
      # On the hosted domain so the mail is not a spoofed From; a self-hoster changes this line
      # together with the recipients above.
      sender_address: %("mcp4mail errors" <no-reply@mcp4mail.online>),
      exception_recipients: ExceptionNotificationRecipients.call
    }
end
