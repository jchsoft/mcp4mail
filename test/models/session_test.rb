require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "belongs to a user and is gone with them" do
    session = users(:one).sessions.create!(user_agent: "t", ip_address: "127.0.0.1")

    assert_equal users(:one), session.user
    assert_difference -> { Session.count }, -1 do
      users(:one).destroy
    end
  end
end
