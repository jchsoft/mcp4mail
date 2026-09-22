require "test_helper"

class OutgoingApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sent = { uidvalidity: 7, messages: [] }
    @server = FakeImapServer.new(capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [ { name: "INBOX" }, { name: "Sent", attrs: [ "Sent" ] } ], mailboxes: { "Sent" => @sent }).start
    @account = mail_accounts(:work)
    @account.update!(host: "127.0.0.1", port: @server.port, ssl: false, smtp_host: "smtp.example.com", smtp_port: 587, smtp_tls: "starttls")
    composer = MessageComposer.new(@account, to: [ "bob@example.org" ], subject: "Lunch", body: "Friday?")
    @outgoing = OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
    Smtp::Sender.delivery_override = :test
    Mail::TestMailer.deliveries.clear
  end

  teardown do
    Smtp::Sender.delivery_override = nil
    @server.stop
  end

  test "the link shows the message with Send and Discard, without signing in" do
    get outgoing_approval_path(@outgoing.raw_token)

    assert_response :success
    assert_select "dd", text: "bob@example.org"
    assert_select "pre", text: "Friday?"
    assert_select "button", text: "Send"
    assert_select "button", text: "Discard"
    assert_empty Mail::TestMailer.deliveries
  end

  test "Send sends it once, and the link then only says it was sent" do
    post outgoing_approval_path(@outgoing.raw_token)

    assert_redirected_to outgoing_approval_path(@outgoing.raw_token)
    assert @outgoing.reload.sent?
    assert_equal [ "bob@example.org" ], Mail::TestMailer.deliveries.sole.to
    assert_equal 1, @sent[:messages].size

    post outgoing_approval_path(@outgoing.raw_token)
    assert_equal 1, Mail::TestMailer.deliveries.size

    follow_redirect!
    assert_select "#outgoing-state", text: "This email has been sent."
    assert_select "button", text: "Send", count: 0
  end

  test "Discard discards it without sending" do
    post outgoing_discard_path(@outgoing.raw_token)

    assert_redirected_to outgoing_approval_path(@outgoing.raw_token)
    assert @outgoing.reload.discarded?
    assert_empty Mail::TestMailer.deliveries
    assert_equal "discarded", McpAuditEvent.sole.outcome
  end

  test "an expired link marks the message expired and cannot send it" do
    @outgoing.update!(expires_at: 1.minute.ago)

    get outgoing_approval_path(@outgoing.raw_token)
    assert_select "#outgoing-state", text: /expired/
    assert @outgoing.reload.expired?

    post outgoing_approval_path(@outgoing.raw_token)
    assert_empty Mail::TestMailer.deliveries
  end

  test "an unknown token is not found" do
    get outgoing_approval_path("not-a-token")

    assert_response :not_found
  end
end
