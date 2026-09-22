require "application_system_test_case"

class RegistrationsTest < ApplicationSystemTestCase
  test "a taken email address is rejected and the form keeps what was typed" do
    visit new_registration_url

    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "long-enough", match: :prefer_exact
    fill_in "Password confirmation", with: "long-enough"
    click_on "Create account"

    assert_selector "#errors", text: "Email address has already been taken"
    assert_field "Email address", with: users(:one).email_address
    screenshot!("registrations-errors-en")
  end

  test "a mismatched confirmation is rejected" do
    visit new_registration_url

    fill_in "Email address", with: "stranger@example.com"
    fill_in "Password", with: "long-enough", match: :prefer_exact
    fill_in "Password confirmation", with: "different"
    click_on "Create account"

    assert_selector "#errors", text: "Password confirmation doesn't match Password"
    assert_field "Email address", with: "stranger@example.com"
  end

  test "a too-short password is rejected" do
    visit new_registration_url

    fill_in "Email address", with: "stranger@example.com"
    fill_in "Password", with: "short12", match: :prefer_exact
    fill_in "Password confirmation", with: "short12"
    # The password field's minlength="8" would otherwise stop the browser from
    # submitting at all, so bypass the native constraint validation the way a
    # request with no JavaScript could.
    page.execute_script("document.querySelector('form').submit()")

    assert_selector "#errors", text: "Password is too short (minimum is 8 characters)"
    assert_field "Email address", with: "stranger@example.com"
  end
end
