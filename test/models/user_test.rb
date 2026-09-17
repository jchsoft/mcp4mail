require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires a unique, well-formed email address" do
    assert_not User.new(email_address: "not-an-email", password: "long-enough").valid?
    assert_not User.new(email_address: users(:one).email_address.upcase, password: "long-enough").valid?
    assert User.new(email_address: "fresh@example.com", password: "long-enough").valid?
  end

  test "requires a password of at least 8 characters" do
    assert_not User.new(email_address: "fresh@example.com", password: "short").valid?
  end
end
