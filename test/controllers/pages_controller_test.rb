require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home page renders" do
    get root_url

    assert_response :success
    assert_select "h1", "mcp4mail"
  end
end
