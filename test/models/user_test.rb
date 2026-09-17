require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalises email address" do
    user = User.create!(email_address: "  Carol@Example.COM ")

    assert_equal "carol@example.com", user.email_address
  end

  test "requires a unique email address" do
    assert_not User.new(email_address: "").valid?
    assert_not User.new(email_address: "ALICE@example.com").valid?
  end
end
