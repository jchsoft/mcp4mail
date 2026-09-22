require "test_helper"

class OutgoingMessageTest < ActiveSupport::TestCase
  # Stands in for an SMTP server that turns the message away.
  class RefusingDelivery
    def initialize(_settings) = nil
    def deliver!(_mail) = raise(SocketError, "connection refused")
  end

  setup do
    @sent = { uidvalidity: 7, messages: [] }
    @server = FakeImapServer.new(capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [ { name: "INBOX" }, { name: "Sent", attrs: [ "Sent" ] } ], mailboxes: { "Sent" => @sent }).start
    @account = mail_accounts(:work)
    @account.update!(host: "127.0.0.1", port: @server.port, ssl: false, smtp_host: "smtp.example.com", smtp_port: 465, smtp_tls: "ssl")
    Smtp::Sender.delivery_override = :test
    Mail::TestMailer.deliveries.clear
  end

  teardown do
    Smtp::Sender.delivery_override = nil
    @server.stop
  end

  test "prepare! stores a pending message with a 24-hour token kept only as a digest" do
    message = prepare

    assert message.pending?
    assert message.awaiting_approval?
    assert_in_delta 24.hours.from_now, message.expires_at, 5
    assert_equal message, OutgoingMessage.find_by_token(message.raw_token)
    assert_not_equal message.raw_token, message.token_digest
    assert_nil OutgoingMessage.find_by_token("not-a-token")
    assert_nil OutgoingMessage.find_by_token(nil)
  end

  test "prepare! refuses an eleventh message waiting in one mailbox" do
    OutgoingMessage::MAX_PENDING_PER_ACCOUNT.times { prepare }

    error = assert_raises(OutgoingMessage::LimitReached) { prepare }
    assert_match "10 messages", error.message
  end

  test "expired and decided messages do not count against the cap" do
    OutgoingMessage::MAX_PENDING_PER_ACCOUNT.times { prepare }
    @account.outgoing_messages.first.update!(expires_at: 1.minute.ago)

    assert_nothing_raised { prepare }
  end

  test "approve! sends, marks it sent and records the owner's answer" do
    message = prepare

    message.approve!(remote_ip: "127.0.0.1")

    assert message.reload.sent?
    assert_not_nil message.sent_at
    delivered = Mail::TestMailer.deliveries.sole
    assert_equal [ "bob@example.org" ], delivered.to
    assert_equal "Hello", delivered.subject
    assert_equal [ "send_message", "sent", @account.id, "claude" ],
      McpAuditEvent.sole.values_at(:tool_name, :outcome, :mail_account_id, :client_id)
    copy = @sent[:messages].sole
    assert_equal [ "\\Seen" ], copy[:flags]
    assert_includes copy[:body], "Subject: Hello"
  end

  test "approve! twice sends once" do
    message = prepare
    message.approve!

    assert_raises(OutgoingMessage::NotPending) { message.approve! }
    assert_equal 1, Mail::TestMailer.deliveries.size
  end

  test "an expired message becomes expired and cannot be sent" do
    message = prepare
    message.update!(expires_at: 1.minute.ago)

    assert_raises(OutgoingMessage::NotPending) { message.approve! }
    assert message.reload.expired?
    assert_empty Mail::TestMailer.deliveries
  end

  test "discard! discards without sending" do
    message = prepare
    message.discard!

    assert message.reload.discarded?
    assert_empty Mail::TestMailer.deliveries
    assert_raises(OutgoingMessage::NotPending) { message.approve! }
  end

  test "a failed send leaves the message pending" do
    message = prepare

    Smtp::Sender.delivery_override = RefusingDelivery

    assert_raises(Smtp::Sender::Failed) { message.approve! }
    assert message.reload.pending?
    assert_empty @sent[:messages]
  end

  private
    def prepare
      composer = MessageComposer.new(@account, to: [ "bob@example.org" ], subject: "Hello", body: "Hi Bob",
        max_recipients: OutgoingMessage::MAX_RECIPIENTS).validate!
      OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
    end
end
