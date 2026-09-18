require "application_system_test_case"

class MailboxActivityTest < ApplicationSystemTestCase
  test "opening the disclosure fetches the mailbox's recent calls" do
    user = users(:one)
    work = mail_accounts(:work)
    Hitch::Client.register!(client_id: "client-abc", client_name: "Claude Desktop", redirect_uris: [ "https://example.com/cb" ])
    McpAuditEvent.create!(user:, mail_account_id: work.id, tool_name: "search_messages", outcome: "ok",
      rows_returned: 7, client_id: "client-abc")
    McpAuditEvent.create!(user:, mail_account_id: work.id, tool_name: "get_message", outcome: "denied",
      rows_returned: 0, client_id: "client-abc")

    visit new_session_url
    fill_in placeholder: "Enter your email address", with: user.email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    visit mail_accounts_url
    assert_text "AI calls today: 2, this week: 2"
    # The frame is fetched only once the disclosure opens, so nothing of the list
    # is on the page before the click.
    assert_no_text "Search messages"

    find("summary", text: "Recent activity").click
    assert_selector "li", text: "Search messages"
    assert_selector "li", text: "Claude Desktop"
    assert_selector "li", text: "rows: 7"
    assert_selector "li", text: "denied"
  end
end
