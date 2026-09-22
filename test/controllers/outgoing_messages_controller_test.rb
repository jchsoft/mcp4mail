require "test_helper"

class OutgoingMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server = FakeImapServer.new(capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [ { name: "INBOX" }, { name: "Sent", attrs: [ "Sent" ] } ], mailboxes: { "Sent" => { uidvalidity: 7, messages: [] } }).start
    @account = mail_accounts(:work)
    @account.update!(host: "127.0.0.1", port: @server.port, ssl: false, smtp_host: "smtp.example.com", smtp_port: 465, smtp_tls: "ssl")
    composer = MessageComposer.new(@account, to: [ "bob@example.org" ], subject: "Lunch", body: "Friday?")
    @outgoing = OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
    Smtp::Sender.delivery_override = :test
    Mail::TestMailer.deliveries.clear
    sign_in_as users(:one)
  end

  teardown do
    Smtp::Sender.delivery_override = nil
    @server.stop
  end

  test "the mailboxes page lists a message waiting for approval with Send and Discard" do
    get mail_accounts_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(@outgoing)}" do
      assert_select "pre", text: "Friday?"
      assert_select "button", text: "Send"
      assert_select "button", text: "Discard"
    end
  end

  test "Send from the mailboxes page sends it" do
    post approve_outgoing_message_path(@outgoing)

    assert_redirected_to mail_accounts_path
    assert_equal "Sent to bob@example.org.", flash[:notice]
    assert @outgoing.reload.sent?
    assert_equal 1, Mail::TestMailer.deliveries.size
  end

  test "Discard from the mailboxes page discards it" do
    post discard_outgoing_message_path(@outgoing)

    assert @outgoing.reload.discarded?
    assert_empty Mail::TestMailer.deliveries
  end

  test "another user's message is not found" do
    sign_in_as users(:two)

    post approve_outgoing_message_path(@outgoing)

    assert_response :not_found
    assert @outgoing.reload.pending?
  end
end
