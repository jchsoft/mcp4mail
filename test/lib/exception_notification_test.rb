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
