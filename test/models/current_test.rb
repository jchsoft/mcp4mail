require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  test "user is delegated to the session and nil without one" do
    assert_nil Current.user

    Current.session = users(:one).sessions.create!(user_agent: "t", ip_address: "127.0.0.1")
    assert_equal users(:one), Current.user
  end
end
