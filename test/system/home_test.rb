require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "visitor sees the landing page" do
    visit root_url

    assert_selector "h1", text: "mcp4mail"
    assert_link "Source on GitHub"
  end
end
