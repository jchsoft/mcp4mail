require "application_system_test_case"

class MailboxAiPermissionsTest < ApplicationSystemTestCase
  PERMISSIONS = [ "Mark as read and flag", "Move messages and create folders", "Write drafts",
                  "Send and reply - always after your approval", "Delete to trash" ].freeze

  test "the permission boxes unfold under the switch and each saves itself" do
    work = mail_accounts(:work)
    sign_in(users(:one))
    visit mail_accounts_url
    assert_no_field "Delete to trash"

    check "Allow the AI to make changes to this mailbox"
    PERMISSIONS.each { |label| assert_checked_field label }
    assert_text "The AI can now make changes to Work."

    uncheck "Delete to trash"
    assert_text "Saved what the AI may do in Work."
    assert_not work.reload.ai_can_trash?

    visit mail_accounts_url
    assert_no_checked_field "Delete to trash"
    assert_checked_field "Write drafts"

    uncheck "Allow the AI to make changes to this mailbox"
    assert_no_field "Delete to trash"
    assert_text "Work is read-only again"

    check "Allow the AI to make changes to this mailbox"
    assert_text "The AI can now make changes to Work."
    assert_no_checked_field "Delete to trash"
    assert_not work.reload.ai_can_trash?
    screenshot!("mailbox-ai-permissions")
  end

  test "the permission boxes are labelled in Czech" do
    mail_accounts(:work).update!(writable: true)
    sign_in(users(:one))
    visit mail_accounts_url(locale: :cs)

    assert_selector "legend", text: "Co smí AI dělat?"
    [ "Označovat jako přečtené a hvězdičkou", "Přesouvat zprávy a vytvářet složky", "Psát koncepty",
      "Odesílat a odpovídat - vždy až po vašem schválení", "Mazat do koše" ].each { |label| assert_checked_field label }
    assert_text "Zapnuto: níže vyberte, co smí měnit."
  end
end
