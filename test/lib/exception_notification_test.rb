require "test_helper"

# Guards config/initializers/exception_notification.rb: where production error emails go. The
# variable is what a self-hoster changes, so what it means (unset, one, several, empty) is worth
# pinning down; the middleware itself is only installed in production and is not booted here.
class ExceptionNotificationTest < ActiveSupport::TestCase
  test "without the variable the hosted instance's operator is told" do
    with_recipients(nil) do
      assert_equal [ "chmel@jchsoft.cz" ], ExceptionNotificationRecipients.call
    end
  end

  test "one or several comma-separated addresses can be given" do
    with_recipients("me@example.org") do
      assert_equal [ "me@example.org" ], ExceptionNotificationRecipients.call
    end

    with_recipients("me@example.org, ops@example.org") do
      assert_equal [ "me@example.org", "ops@example.org" ], ExceptionNotificationRecipients.call
    end
  end

  test "an empty value switches the emails off" do
    with_recipients("") do
      assert_empty ExceptionNotificationRecipients.call
    end
  end

  test "the error email leaves out the raw form, so a mailbox password is never mailed" do
    env = Rack::MockRequest.env_for("https://mcp4mail.example/mail_accounts",
      method: "POST", params: { mail_account: { host: "imap.example.org", password: "s3cret-app-password" } })
      .merge(Rails.application.env_config) # the parameter filter the app installs
    Rack::Request.new(env).POST # what the exception report showed: rack.request.form_pairs
    exception = RuntimeError.new("boom").tap { |e| e.set_backtrace([ "app/controllers/mail_accounts_controller.rb:70" ]) }

    email = ExceptionNotifier::EmailNotifier.new(ExceptionNotificationEmail.options).create_email(exception, env: env)

    assert_includes email.body.to_s, "imap.example.org"
    assert_not_includes email.body.to_s, "s3cret-app-password"
  end

  private
    # Minitest 6 has no Object#stub; the variable is swapped by hand, as in FakeAutodetectNetwork.
    def with_recipients(value)
      before = ENV["EXCEPTION_NOTIFICATION_RECIPIENTS"]
      ENV["EXCEPTION_NOTIFICATION_RECIPIENTS"] = value
      yield
    ensure
      ENV["EXCEPTION_NOTIFICATION_RECIPIENTS"] = before
    end
end
