require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "signing in with valid credentials lands on the root page, signed in" do
    visit new_session_url
    assert_field placeholder: "Enter your email address"
    assert_field placeholder: "Enter your password"
    # The placeholders stay for the tests that fill by them; the labels are what
    # names the fields for a screen reader, and only shared/_field supplies them.
    assert_field "Email address", type: "email"
    assert_field "Password", type: "password"

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
      11.times { submit_counted_sign_in(counts) }
    end

    assert_operator counts.values.sum, :>, 10
    assert_selector "#alert", text: "Try again later."
  end

  private
    # The alert stays on screen across attempts (every attempt shows one), so it
    # can't tell one attempt from the next. Waiting for Turbo to re-enable the
    # button wasn't enough either: under parallel workers a click now and then
    # never became a request, fewer than 11 reached the server and the limiter
    # never tripped (task #13337). So each attempt waits until the controller
    # has counted it, and a click that never arrived is made again. Turbo keeps
    # the button disabled from submit until the redirect's page renders, so once
    # the count moved, waiting for an enabled button waits for that page.
    def submit_counted_sign_in(counts)
      before = counts.values.sum
      2.times do
        fill_in placeholder: "Enter your email address", with: users(:one).email_address
        fill_in placeholder: "Enter your password", with: "wrong-password"
        click_button "Sign in"
        next unless counted?(counts, before)

        assert_button "Sign in"
        return
      end
      flunk "the sign-in form was submitted twice and neither submission reached the server"
    end

    def counted?(counts, before)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      until counts.values.sum > before
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.05
      end
      true
    end

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
