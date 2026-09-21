require "application_system_test_case"

class MailboxWritableSwitchTest < ApplicationSystemTestCase
  test "flipping the switch saves it at once, without a save button" do
    user = users(:one)
    work = mail_accounts(:work)

    visit new_session_url
    fill_in placeholder: "Enter your email address", with: user.email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    visit mail_accounts_url
    assert_text "Off: the AI can only read and search."
    assert_no_button "Save"

    check "Allow the AI to make changes to this mailbox"
    assert_text "The AI can now make changes to Work."
    assert_checked_field "Allow the AI to make changes to this mailbox"
    assert work.reload.writable?

    uncheck "Allow the AI to make changes to this mailbox"
    assert_text "Work is read-only again"
    assert_not work.reload.writable?
  end
end
