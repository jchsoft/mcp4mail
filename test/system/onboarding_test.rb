require "application_system_test_case"
require_relative "../support/fake_autodetect_network"

class OnboardingTest < ApplicationSystemTestCase
  include FakeAutodetectNetwork

  # Detection has its own tests; here it only has to point at the local fake server, the way
  # it would point at a real provider. The app server runs in this process, so the swap holds.
  def detecting(server, &block)
    result = Imap::Autodetect::Result.new(host: "127.0.0.1", port: server.port, tls: :none, username: "bob", source: :autoconfig)
    replace_singleton(Imap::Autodetect, :call, ->(**) { result }, &block)
  end

  test "a stranger signs up, adds a mailbox and finds the Connect AI instructions" do
    server = FakeImapServer.new.start

    visit root_url
    # The header carries a "Connect a mailbox" link too, so aim at the hero's —
    # the first of the landing page's sections.
    within("main section:first-of-type") { click_on "Connect a mailbox" }

    fill_in "Email address", with: "stranger@example.com"
    fill_in "Password", with: "long-enough", match: :prefer_exact
    fill_in "Password confirmation", with: "long-enough"
    click_on "Create account"

    assert_selector "h1", text: "Add a mailbox"

    assert_no_selector "#connection-details[open]"
    assert_text "Use an app-specific password if your provider offers one."
    fill_in "Email address", with: "bob@example.com"
    fill_in "Password", with: "app-password"
    detecting(server) do
      click_on "Connect"
      assert_text "Connected bob@example.com"
    end
    assert_selector "li", text: "bob · 127.0.0.1:#{server.port}"

    click_on "Next: connect your AI app"
    assert_selector "h1", text: "Connect AI"
    assert_selector "#client-claude", text: "Add custom connector"
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
    fill_in "Email address", with: "bob@example.com"
    fill_in "Password", with: "wrong"
    find("summary", text: "Connection details").click
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: server.port
    select "None (unencrypted)", from: "Security"
    fill_in "Username", with: "bob"
    click_on "Connect"

    assert_selector "#connection-error", text: "rejected the username or password"
    assert_selector "#connection-details[open]"
    assert_field "IMAP server", with: "127.0.0.1"
  ensure
    server&.stop
  end

  test "the language switcher shows the pages in Czech" do
    visit connect_ai_url
    within("#language-switcher") { click_on "CS" }

    assert_selector "h1", text: "Propojit s AI"
    assert_selector "#client-claude", text: "V claude.ai nebo Claude Desktop"
  end
end
