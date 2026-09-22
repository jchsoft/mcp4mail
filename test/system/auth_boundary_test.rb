require "application_system_test_case"

class AuthBoundaryTest < ApplicationSystemTestCase
  test "signed out, the mailbox pages send the visitor to sign in and back to the page they asked for" do
    user = users(:one)
    work = mail_accounts(:work)

    [ mail_accounts_path, new_mail_account_path, activity_mail_account_path(work) ].each do |path|
      visit path
      assert_current_path new_session_path

      sign_in_on_form(user)
      assert_current_path path

      click_sign_out
    end
  end

  test "a session deleted mid-visit sends the next click to sign in, and signing in finishes that click" do
    user = users(:one)

    sign_in(user)
    visit mail_accounts_url
    assert_link "Add mailbox"

    user.sessions.delete_all
    click_on "Add mailbox"

    assert_current_path new_session_path
    screenshot!("auth-session-expired-en")

    sign_in_on_form(user)
    assert_current_path new_mail_account_path
  end

  test "a dropped session cookie sends the next click to sign in" do
    user = users(:one)

    sign_in(user)
    visit mail_accounts_url
    assert_link "Add mailbox"

    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Add mailbox"

    assert_current_path new_session_path
    assert Session.exists?(user_id: user.id), "the server-side session is untouched; only this browser lost it"
  end

  private
    # Every system test signs in through the form; there is no test-only shortcut, the
    # same as mailbox_lifecycle_test.rb and the other mailbox system tests.
    def sign_in(user)
      visit new_session_url
      sign_in_on_form(user)
      assert_current_path root_path
    end

    def sign_in_on_form(user)
      fill_in placeholder: "Enter your email address", with: user.email_address
      fill_in placeholder: "Enter your password", with: "password"
      click_button "Sign in"
    end

    def click_sign_out
      click_button "Sign out"
      assert_current_path new_session_path
    end
end
