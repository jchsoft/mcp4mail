require "test_helper"

class ConnectAiControllerTest < ActionDispatch::IntegrationTest
  test "shows the server URL, the authorization note and one panel per client without signing in" do
    get connect_ai_path

    assert_response :success
    assert_select "#server-url[value=?]", Hitch.configuration.resource_uri
    assert_select "#authorization-note", /Authorization happens in your browser/
    %w[ claude chatgpt cursor other ].each do |client|
      assert_select "[role=tab]#tab-#{client}"
      assert_select "[role=tabpanel]#client-#{client} p"
    end
  end

  test "keeps every instruction to two sentences at most" do
    get connect_ai_path

    assert_select "[role=tabpanel] p" do |paragraphs|
      paragraphs.each { |p| assert_operator p.text.scan(/\. |\.\z/).size, :<=, 2, p.text }
    end
  end

  test "translates the instructions" do
    get connect_ai_path(locale: "cs")

    assert_select "#client-other", /vzdálený MCP server/
    assert_select "#authorization-note", /mcp4mail po vás nikdy nechce žádný token/
  end

  test "reminds a signed-in user without a mailbox to add one, above the URL" do
    sign_in_as users(:one)
    users(:one).mail_accounts.destroy_all

    get connect_ai_path
    assert_select "#no-mailbox a[href=?]", new_mail_account_path
    assert_select "#server-url"
  end

  test "says nothing about mailboxes when the user has one" do
    sign_in_as users(:one)

    get connect_ai_path
    assert_select "#no-mailbox", false
  end
end
