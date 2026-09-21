require "test_helper"

class SharedErrorSummaryTest < ActionView::TestCase
  test "lists every message in #errors on the danger tokens" do
    user = User.new.tap do |record|
      record.errors.add(:email_address, :taken)
      record.errors.add(:password, :blank)
    end
    render "shared/error_summary", model: user

    assert_select "ul#errors.bg-danger-tint.border-danger > li", 2
    assert_select "ul#errors li", "Email address has already been taken"
  end

  test "renders nothing for a valid record" do
    render "shared/error_summary", model: User.new

    assert_empty rendered.strip
  end
end
