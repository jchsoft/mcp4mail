require "application_system_test_case"

class OnboardingTest < ApplicationSystemTestCase
  test "a stranger signs up, adds a mailbox and finds the Connect AI instructions" do
    server = FakeImapServer.new.start

    visit root_url
    # The header carries a "Connect a mailbox" link too, so aim at the hero's.
    within("main section") { click_on "Connect a mailbox" }

    fill_in "Email address", with: "stranger@example.com"
    fill_in "Password", with: "long-enough", match: :prefer_exact
    fill_in "Password confirmation", with: "long-enough"
    click_on "Create account"

    assert_selector "h1", text: "Add a mailbox"

    select "Gmail / Google Workspace", from: "Provider"
    assert_field "IMAP server", with: "imap.gmail.com"
    assert_field "Port", with: "993"
    assert_checked_field "SSL/TLS"
    assert_text "app password"

    select "Other - I will enter the server myself", from: "Provider"
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: server.port
    uncheck "SSL/TLS"
    fill_in "Username", with: "bob"
    fill_in "Password", with: "app-password"
    fill_in "Name (optional)", with: "Fake"
    click_on "Test connection and add"

    assert_text "Mailbox Fake added"
    assert_selector "li", text: "bob · 127.0.0.1:#{server.port}"

    click_on "Next: connect your AI app"
    assert_selector "h1", text: "Connect AI"
    assert_selector "#client-grok", text: "Allow pop-ups for grok.com"
    assert_no_selector "#no-mailbox"
  ensure
    server&.stop
  end

  test "a failed connection test keeps the user on the form with a hint" do
    server = FakeImapServer.new(login_ok: false).start
    user = users(:one)

    visit new_session_url
    fill_in placeholder: "Enter your email address", with: user.email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    # Wait for the sign-in redirect, or the next visit races the session cookie.
    assert_current_path root_path

    visit new_mail_account_url
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: server.port
    uncheck "SSL/TLS"
    fill_in "Username", with: "bob"
    fill_in "Password", with: "wrong"
    click_on "Test connection and add"

    assert_selector "#connection-error", text: "rejected the username or password"
    assert_field "IMAP server", with: "127.0.0.1"
  ensure
    server&.stop
  end

  test "the language switcher shows the pages in Czech" do
    visit connect_ai_url
    within("#language-switcher") { click_on "CS" }

    assert_selector "h1", text: "Propojit s AI"
    assert_selector "#client-grok", text: "Povolte vyskakovací okna pro grok.com"
  end
end
