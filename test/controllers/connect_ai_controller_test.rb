require "test_helper"

class ConnectAiControllerTest < ActionDispatch::IntegrationTest
  test "shows the server URL and instructions for every client without signing in" do
    get connect_ai_path

    assert_response :success
    assert_select "#server-url[value=?]", Hitch.configuration.resource_uri
    %w[ claude chatgpt grok cursor ].each { |client| assert_select "#client-#{client} ol li" }
    assert_select "#client-cursor pre", /"url": "#{Regexp.escape(Hitch.configuration.resource_uri)}"/
  end

  test "tells Grok users to allow pop-ups, because Safari blocks the sign-in window" do
    get connect_ai_path
    assert_select "#client-grok li", /Allow pop-ups for grok.com.*Safari/

    get connect_ai_path(locale: "cs")
    assert_select "#client-grok li", /Povolte vyskakovací okna pro grok.com.*Safari/
  end

  test "reminds a signed-in user without a mailbox to add one" do
    sign_in_as users(:one)
    users(:one).mail_accounts.destroy_all

    get connect_ai_path
    assert_select "#no-mailbox"
  end
end
