require "application_system_test_case"

# The page behind the link in the approval email, opened in a browser with no session: the
# token is the whole credential. The SMTP hop is Smtp::Sender's :test delivery; the Sent copy
# goes to a fake IMAP server on 127.0.0.1.
class OutgoingApprovalTest < ApplicationSystemTestCase
  setup do
    @sent = { uidvalidity: 7, messages: [] }
    @server = FakeImapServer.new(capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [ { name: "INBOX" }, { name: "Sent", attrs: [ "Sent" ] } ], mailboxes: { "Sent" => @sent }).start
    account = mail_accounts(:work)
    account.update!(host: "127.0.0.1", port: @server.port, ssl: false, smtp_host: "smtp.example.com", smtp_port: 587, smtp_tls: "starttls")
    composer = MessageComposer.new(account, to: [ "bob@example.org" ], subject: "Lunch", body: "Friday?")
    @outgoing = OutgoingMessage.prepare!(mail_account: account, client_id: "claude", composer:)
    Smtp::Sender.delivery_override = :test
    Mail::TestMailer.deliveries.clear
  end

  teardown do
    Smtp::Sender.delivery_override = nil
    @server.stop
  end

  test "opening the link, then Send, sends the message" do
    visit outgoing_approval_url(@outgoing.raw_token)

    assert_text "Friday?"
    assert_text "bob@example.org"
    screenshot!("outgoing-approval-en")

    click_button "Send"

    assert_selector "#notice"
    assert_selector "#outgoing-state", text: "This email has been sent."
    assert_no_button "Send"
    assert_equal [ "bob@example.org" ], Mail::TestMailer.deliveries.sole.to
    screenshot!("outgoing-sent-en")
  end

  test "Discard throws the message away without sending it" do
    visit outgoing_approval_url(@outgoing.raw_token)

    click_button "Discard"

    assert_selector "#outgoing-state"
    assert_no_button "Send"
    assert @outgoing.reload.discarded?
    assert_empty Mail::TestMailer.deliveries
    screenshot!("outgoing-discarded-en")
  end
end
