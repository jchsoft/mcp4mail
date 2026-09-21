require "application_system_test_case"

class GuidesTest < ApplicationSystemTestCase
  test "visitor opens the Seznam guide from the guides index" do
    visit guides_url

    assert_selector "h1", text: "Set up your mailbox"
    click_link "Seznam.cz (Email.cz)"

    assert_current_path guide_path("seznam")
    assert_selector "h1", text: "Seznam.cz (Email.cz)"
    assert_text "imap.seznam.cz"
    assert_selector ".guide-prose h2", text: "1. Switch on IMAP in Seznam"
    assert_link "Connect a mailbox", href: new_mail_account_path
    assert_link "← All guides", href: guides_path
  end
end
