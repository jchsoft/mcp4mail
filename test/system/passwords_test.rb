require "application_system_test_case"

class PasswordsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "the full journey: request, email, reset, sign in with the new password" do
    user = users(:one)

    visit new_password_url
    assert_field placeholder: "Enter your email address"

    perform_enqueued_jobs do
      fill_in placeholder: "Enter your email address", with: user.email_address
      click_button "Email reset instructions"
    end

    assert_current_path new_session_path
    assert_selector "#notice", text: "Password reset instructions sent"
    screenshot!("passwords-request-sent-en")

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ user.email_address ], mail.to
    token = mail.body.encoded[%r{/passwords/([^/\s"]+)/edit}, 1]
    assert token.present?, "expected a password reset link in the delivered mail"

    visit edit_password_path(token)
    assert_field placeholder: "Enter new password"

    fill_in placeholder: "Enter new password", with: "new-password"
    fill_in placeholder: "Repeat new password", with: "new-password"
    click_button "Save"

    assert_current_path new_session_path
    assert_selector "#notice", text: "Password has been reset."
    screenshot!("passwords-reset-done-en")

    fill_in placeholder: "Enter your email address", with: user.email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_selector "#alert", text: "Try another email address or password."

    fill_in placeholder: "Enter your password", with: "new-password"
    click_button "Sign in"
    assert_current_path root_path
  end

  test "a tampered or expired token redirects to the request form with an alert" do
    visit edit_password_url("not-a-real-token")

    assert_current_path new_password_path
    assert_selector "#alert", text: "Password reset link is invalid or has expired."
    screenshot!("passwords-invalid-token-en")
  end

  test "a mismatched confirmation redirects back to the reset form with an alert" do
    token = users(:one).password_reset_token

    visit edit_password_path(token)
    fill_in placeholder: "Enter new password", with: "new-password"
    fill_in placeholder: "Repeat new password", with: "different-password"
    click_button "Save"

    assert_current_path edit_password_path(token)
    assert_selector "#alert", text: "Passwords did not match."
  end

  test "rapid reset requests trip the rate limiter" do
    counts = Hash.new(0)
    real_increment(counts) do
      # Unlike SessionsTest's failed sign-in, a successful request redirects
      # away from the form, so each attempt starts with a fresh visit rather
      # than reusing the page a click just submitted.
      11.times do
        visit new_password_url
        fill_in placeholder: "Enter your email address", with: users(:one).email_address
        click_button "Email reset instructions"
      end
    end

    assert_selector "#alert", text: "Try again later."
  end

  private
    # Rails.cache is a NullStore in test, so rate_limit's cache.increment is a
    # no-op and the limiter never trips. Same swap as SessionsTest.
    def real_increment(counts, &block)
      meta = Rails.cache.singleton_class
      meta.send(:define_method, :increment) { |key, amount = 1, **| counts[key] += amount }
      yield
    ensure
      meta.send(:remove_method, :increment)
    end
end
