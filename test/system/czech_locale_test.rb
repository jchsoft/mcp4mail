require "application_system_test_case"

# Czech is a first-class locale, but only connect_ai_test.rb (task #12770) had ever
# exercised it. This walks the signed-in surface the same way: translated headings,
# labels, buttons, flash messages and the Turbo confirm text, which comes from a
# locale key of its own (data-turbo-confirm) and is easy to leave in English.
class CzechLocaleTest < ApplicationSystemTestCase
  test "an invalid sign-in shows the Czech alert and keeps the typed address" do
    user = users(:one)

    visit new_session_url(locale: :cs)
    assert_selector "h1", text: "Přihlášení"
    fill_in placeholder: "Zadejte e-mailovou adresu", with: user.email_address
    fill_in placeholder: "Zadejte heslo", with: "wrong-password"
    click_button "Přihlásit se"

    assert_selector "#alert", text: "Zkuste jinou e-mailovou adresu nebo heslo."
    assert_field placeholder: "Zadejte e-mailovou adresu", with: user.email_address
    screenshot!("sessions-invalid-credentials-cs")
  end

  test "switching language mid-form keeps the visitor on the same page" do
    user = users(:one)

    sign_in(user)
    visit new_mail_account_url
    fill_in "Email address", with: "bob@example.com"

    # url_for(locale:) recalls the current controller/action (shared/_locale_switcher.html.erb),
    # so switching language re-renders this same form instead of sending the visitor home.
    within("#language-switcher") { click_on "CS" }

    assert_current_path new_mail_account_path(locale: "cs")
    assert_selector "h1", text: "Přidat schránku"
  end

  test "the mailboxes list, its activity disclosure, the writable switch and removal show Czech copy" do
    user = users(:one)
    work = mail_accounts(:work)

    sign_in(user)
    visit mail_accounts_url(locale: :cs)

    assert_selector "h1", text: "Schránky"
    assert_link "Přidat schránku"
    within("header") do
      assert_link "Schránky"
      assert_link "Propojit s AI"
      assert_button "Odhlásit se"
    end
    assert_selector "#mail_account_#{work.id}", text: work.label
    assert_text "Volání AI 0 dnes 0 tento týden", normalize_ws: true
    assert_selector "label", text: "Povolit AI měnit tuto schránku"
    screenshot!("mailboxes-list-cs")

    open_activity_disclosure "Poslední aktivita"
    assert_text "Do této schránky zatím žádná AI nesáhla."
    screenshot!("mailbox-activity-empty-cs")

    check "Povolit AI měnit tuto schránku"
    assert_text "AI teď může měnit schránku #{work.label}."
    assert work.reload.writable?

    accept_confirm(/Odebrat schránku #{Regexp.escape(work.label)}\?/) do
      click_on "Odebrat"
    end
    assert_selector "#notice", text: "Schránka #{work.label} je odebraná."
    assert_no_selector "#mail_account_#{work.id}"
    assert_not MailAccount.exists?(work.id)
    screenshot!("mailbox-removed-cs")
  end

  test "the account page shows Czech copy, including the delete confirmation" do
    user = users(:one)

    sign_in(user)
    visit account_url(locale: :cs)

    assert_selector "h1", text: "Váš účet"
    assert_selector "#account-summary", text: user.email_address
    assert_selector "#download-my-data", text: "Stáhnout moje data"
    assert_selector "#delete-my-account", text: "Smazat můj účet"
    screenshot!("account-cs")

    accept_confirm(/Smazat váš účet\?/) do
      within("#delete-my-account") { click_on "Smazat můj účet" }
    end
    assert_text "Váš účet i všechno, co jsme o něm drželi, je pryč."
    assert_not User.exists?(user.id)
  end

  private
    # Every system test signs in through the form; there is no test-only shortcut, the
    # same as onboarding_test.rb and the other mailbox system tests.
    def sign_in(user)
      visit new_session_url
      fill_in placeholder: "Enter your email address", with: user.email_address
      fill_in placeholder: "Enter your password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end
end
