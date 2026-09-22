require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signing in with valid credentials lands on the root page, signed in" do
    visit new_session_url
    assert_field placeholder: "Enter your email address"
    assert_field placeholder: "Enter your password"

    fill_in placeholder: "Enter your email address", with: users(:one).email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"

    assert_current_path root_path
    screenshot!("sessions-signed-in-en")

    # The root page keeps the marketing header even when signed in (only its call
    # to action changes, covered by home_test.rb); the signed-in nav (Mailboxes,
    # sign out) lives on the app pages behind it.
    visit mail_accounts_url
    within("header") do
      assert_link "Mailboxes"
      assert_button "Sign out"
    end
  end

  test "invalid credentials keep the typed email and show the alert" do
    visit new_session_url
    fill_in placeholder: "Enter your email address", with: users(:one).email_address
    fill_in placeholder: "Enter your password", with: "wrong-password"
    click_button "Sign in"

    assert_current_path new_session_path(email_address: users(:one).email_address)
    assert_selector "#alert", text: "Try another email address or password."
    assert_field placeholder: "Enter your email address", with: users(:one).email_address
    screenshot!("sessions-invalid-credentials-en")
  end

  test "signing out ends the session and the mailboxes page is no longer reachable" do
    visit new_session_url
    fill_in placeholder: "Enter your email address", with: users(:one).email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    visit mail_accounts_url
    within("header") { click_button "Sign out" }

    assert_current_path new_session_path

    visit mail_accounts_url
    assert_current_path new_session_path
  end

  test "rapid sign-in attempts trip the rate limiter" do
    counts = Hash.new(0)
    real_increment(counts) do
      visit new_session_url
      11.times do
        fill_in placeholder: "Enter your email address", with: users(:one).email_address
        fill_in placeholder: "Enter your password", with: "wrong-password"
        click_button "Sign in"
        # The alert stays on screen across iterations (every attempt shows one),
        # so asserting on it doesn't wait for anything past the first attempt.
        # Turbo disables the submit button for the duration of the request and
        # only re-enables it once the redirect's page has rendered, so wait for
        # that instead, or a fast loop can fill and click a page Turbo is about
        # to replace, and the submission never reaches the server.
        assert_button "Sign in"
      end
    end

    assert_selector "#alert", text: "Try again later."
  end

  private
    # Rails.cache is a NullStore in test, so `rate_limit`'s cache.increment is a
    # no-op and the limiter never trips (SessionsController#cache_store is that
    # very NullStore instance, captured once when the class loaded). Minitest 6
    # dropped Object#stub, so the swap is a singleton method, same as
    # test/support/fake_autodetect_network.rb.
    def real_increment(counts, &block)
      meta = Rails.cache.singleton_class
      meta.send(:define_method, :increment) { |key, amount = 1, **| counts[key] += amount }
      yield
    ensure
      meta.send(:remove_method, :increment)
    end
end
