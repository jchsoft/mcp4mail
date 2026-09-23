require "application_system_test_case"

class MailboxLifecycleTest < ApplicationSystemTestCase
  test "a signed-in user with no mailboxes sees the empty state" do
    user = User.create!(email_address: "fresh@example.com", password: "password")

    sign_in(user)
    visit mail_accounts_url

    assert_selector "#empty", text: "Connect your first mailbox"
    assert_link "Add mailbox"
    assert_no_selector "summary", text: "Recent activity"
    screenshot!("mailbox-empty-en")
  end

  test "invalid connection details show the errors without attempting a connection" do
    user = users(:one)

    sign_in(user)
    visit new_mail_account_url
    fill_in "Email address", with: "bob@example.com"
    fill_in "Password", with: "app-password"
    find("summary", text: "Connection details").click
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: ""
    fill_in "Username", with: "bob"
    click_on "Connect"

    assert_selector "#errors", text: "Port"
    assert_selector "#connection-details[open]"
    assert_no_selector "#connection-error"
    assert_field "IMAP server", with: "127.0.0.1"
    assert_field "Username", with: "bob"
    screenshot!("mailbox-validation-error-en")
  end

  test "an unreachable server and a TLS mismatch each show their own connection error" do
    user = users(:one)
    dead_server = FakeImapServer.new.start
    dead_port = dead_server.port
    dead_server.stop
    trap_server = FakeImapServer.tls_trap

    sign_in(user)

    visit new_mail_account_url
    fill_in "Email address", with: "bob@example.com"
    fill_in "Password", with: "app-password"
    find("summary", text: "Connection details").click
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: dead_port
    select "None (unencrypted)", from: "Security"
    fill_in "Username", with: "bob"
    # The submit button's turbo_submits_with state is not asserted here: both a
    # loopback ECONNREFUSED and a failed local TLS handshake resolve too fast for a
    # headless browser to reliably observe the swapped-in "Finding your mail
    # server…" text before the error response replaces it.
    click_on "Connect"

    assert_selector "#connection-error", text: "could not be reached"
    assert_selector "#connection-details[open]"
    assert_field "IMAP server", with: "127.0.0.1"
    assert_field "Port", with: dead_port.to_s
    screenshot!("mailbox-connection-unreachable-en")

    # The password field never echoes the previous value back (Rails' password_field
    # always renders blank), so it needs refilling before the second attempt.
    fill_in "Password", with: "app-password"
    fill_in "Port", with: trap_server.port
    select "SSL/TLS", from: "Security"
    click_on "Connect"

    assert_selector "#connection-error", text: "secure connection to the server failed"
    assert_no_text "could not be reached"
    assert_field "Port", with: trap_server.port.to_s
    screenshot!("mailbox-connection-tls-en")
  ensure
    trap_server&.stop
  end

  test "removing a mailbox asks for confirmation, and dismissing it changes nothing" do
    user = users(:one)
    work = mail_accounts(:work)

    sign_in(user)
    visit mail_accounts_url

    dismiss_confirm do
      click_on "Remove"
    end
    assert_selector "#mail_account_#{work.id}"
    assert MailAccount.exists?(work.id)

    accept_confirm do
      click_on "Remove"
    end
    assert_selector "#notice", text: "Mailbox Work removed."
    assert_no_selector "#mail_account_#{work.id}"
    assert_not MailAccount.exists?(work.id)
    screenshot!("mailbox-removed-en")
  end

  test "a mailbox whose last sync failed shows the error on the index" do
    user = users(:one)
    work = mail_accounts(:work)
    work.update_columns(last_error: "connection reset by peer")

    sign_in(user)
    visit mail_accounts_url

    assert_selector "#last_error_mail_account_#{work.id}", text: "Last connection failed: connection reset by peer"
    screenshot!("mailbox-broken-en")
  end

  test "a long display name and a unicode label do not break the mailbox row" do
    user = users(:one)
    long_name = "Archive " * 25
    emoji_name = "📬 Poštovní schránka — ünïcödé"
    long_account = user.mail_accounts.create!(display_name: long_name, host: "imap.example.org",
      username: "long@example.com", password: "fixture-app-password")
    emoji_account = user.mail_accounts.create!(display_name: emoji_name, host: "imap.example.org",
      username: "emoji@example.com", password: "fixture-app-password")

    sign_in(user)
    visit mail_accounts_url

    assert_selector "#mail_account_#{long_account.id}", text: long_name.strip
    assert_selector "#mail_account_#{emoji_account.id}", text: emoji_name
    assert_selector "#mail_account_#{mail_accounts(:work).id}"
    screenshot!("mailbox-awkward-data-en")

    accept_confirm(/#{Regexp.escape(emoji_name)}/) do
      within("#mail_account_#{emoji_account.id}") { click_on "Remove" }
    end
    assert_no_selector "#mail_account_#{emoji_account.id}"
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
