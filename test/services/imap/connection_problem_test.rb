require "test_helper"

class Imap::ConnectionProblemTest < ActiveSupport::TestCase
  def problem(reason, email = "bob@example.com", raw_response: nil)
    Imap::ConnectionProblem.call(reason: reason, email: email, raw_response: raw_response)
  end

  %w[icloud.com me.com mac.com fastmail.com zoho.com yahoo.com yandex.com].each do |domain|
    test "asks #{domain} users for an app-specific password when login is refused" do
      result = problem(:auth_failed, "bob@#{domain}", raw_response: "NO [AUTHENTICATIONFAILED] Invalid credentials")

      assert_equal :app_password, result.key
      assert_match(/app-specific password/, result.message)
      assert_includes result.message, result.provider
    end
  end

  test "names iCloud in its own message" do
    assert_match(/\AiCloud does not accept your normal password here/, problem(:auth_failed, "bob@icloud.com").message)
  end

  %w[seznam.cz email.cz post.cz].each do |domain|
    test "tells #{domain} users to switch IMAP on" do
      %i[auth_failed imap_disabled].each do |reason|
        assert_equal :seznam_imap_off, problem(reason, "bob@#{domain}").key
      end
    end
  end

  test "explains Proton Bridge when no server is found" do
    %w[proton.me protonmail.com pm.me].each do |domain|
      result = problem(:no_server_found, "bob@#{domain}")

      assert_equal :bridge_required, result.key
      assert_match(/Proton Bridge/, result.message)
    end
  end

  test "points Gmail and Outlook at the native connector whatever went wrong" do
    %w[gmail.com outlook.com hotmail.com].each do |domain|
      %i[auth_failed timeout no_server_found].each do |reason|
        result = problem(reason, "bob@#{domain}")

        assert_equal :native_connector, result.key
        assert_match(/native connector in Claude and ChatGPT/, result.message)
      end
    end
  end

  test "has three distinct generic messages for wrong password, unknown host and timeout" do
    keys = { auth_failed: :wrong_password, no_server_found: :unknown_host, timeout: :timeout }

    keys.each { |reason, key| assert_equal key, problem(reason).key }
    assert_equal 3, keys.keys.map { |reason| problem(reason).message }.uniq.size
    assert_nil problem(:auth_failed).provider
  end

  test "generic IMAP-disabled message" do
    assert_equal :imap_disabled, problem(:imap_disabled).key
  end

  test "an unknown provider whose server asks for an app password gets the generic app-password message" do
    result = problem(:auth_failed, raw_response: "NO Application-specific password required")

    assert_equal :app_password_generic, result.key
  end

  test "keeps a provider's other reasons on the generic messages" do
    assert_equal :timeout, problem(:timeout, "bob@icloud.com").key
  end

  test "matches the domain case-insensitively and copes with a blank address" do
    assert_equal :app_password, problem(:auth_failed, "Bob@ICLOUD.com").key
    assert_equal :unknown_host, problem(:no_server_found, "").key
  end

  test "carries the guide slug, nil until a guide exists" do
    assert_not problem(:auth_failed, "bob@icloud.com").guide?
  end

  test "every message key used by the providers file exists in the locale" do
    Imap::ConnectionProblem::PROVIDERS.each_value do |entry|
      entry["messages"].each_value { |key| assert I18n.exists?("imap_problems.#{key}"), key }
    end
  end
end
