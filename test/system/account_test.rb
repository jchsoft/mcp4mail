require "application_system_test_case"

class AccountTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in
  end

  test "the account page shows what is held and both GDPR buttons" do
    visit account_url

    assert_selector "h1", text: "Your account"
    assert_selector "#account-summary", text: @user.email_address
    assert_selector "#download-my-data a", text: "Download my data"
    assert_selector "#delete-my-account", text: "Delete my account"
  end

  test "deleting the account takes the mailboxes with it and signs the person out" do
    visit account_url

    accept_confirm(/Delete your account\?/) { within("#delete-my-account") { click_on "Delete my account" } }

    assert_text "Your account and everything we held about it are gone"
    assert_no_selector "nav a", text: "Mailboxes"
    assert_not User.exists?(@user.id)
  end

  test "the landing page shows who is signed in, one click from the account page" do
    visit root_url

    within("header") { assert_link @user.email_address }
    screenshot!("landing-header-signed-in")

    within("header") { click_link @user.email_address }
    assert_current_path account_path
    assert_selector "h1", text: "Your account"
  end

  private
    def sign_in
      visit new_session_url
      fill_in placeholder: "Enter your email address", with: @user.email_address
      fill_in placeholder: "Enter your password", with: "password"
      click_button "Sign in"
      # Wait for the sign-in redirect, or the next visit races the session cookie.
      assert_current_path root_path
    end
end
