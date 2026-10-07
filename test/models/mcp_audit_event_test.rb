require "test_helper"

class McpAuditEventTest < ActiveSupport::TestCase
  Context = Struct.new(:principal, :client_id, :remote_ip)

  setup do
    @user = users(:one)
    @account = mail_accounts(:work)
    @context = Context.new(@user, "claude", "127.0.0.1")
  end

  test "record! stores the call without its arguments" do
    event = McpAuditEvent.record!(context: @context, tool_name: "search_messages", outcome: "ok",
      mail_account_id: @account.id, rows_returned: 3, duration_ms: 12)

    assert_equal [ @user.id, "claude", "127.0.0.1", 3, 12 ], [ event.user_id, event.client_id, event.remote_ip, event.rows_returned, event.duration_ms ]
  end

  test "validates outcome and rows_returned" do
    event = McpAuditEvent.new(user: @user, tool_name: "x", client_id: "c", outcome: "weird", rows_returned: -1)

    assert_not event.valid?
    assert event.errors.key?(:outcome)
    assert event.errors.key?(:rows_returned)
  end

  test "denied? reflects the outcome" do
    assert_predicate McpAuditEvent.new(outcome: "denied"), :denied?
    assert_not McpAuditEvent.new(outcome: "ok").denied?
  end

  test "for_account, since and count_by_account scope by mailbox and time" do
    mine = McpAuditEvent.record!(context: @context, tool_name: "t", outcome: "ok", mail_account_id: @account.id)
    McpAuditEvent.record!(context: @context, tool_name: "t", outcome: "ok")
    old = McpAuditEvent.record!(context: @context, tool_name: "t", outcome: "ok", mail_account_id: @account.id)
    old.update!(created_at: 2.days.ago)

    assert_equal [ mine, old ].sort_by(&:id), McpAuditEvent.for_account(@account).order(:id).to_a
    assert_equal [ mine ], McpAuditEvent.for_account(@account).since(1.day.ago).to_a
    assert_equal({ @account.id => 1 }, McpAuditEvent.count_by_account(since: 1.day.ago))
  end

  test "recent is newest first and capped" do
    (McpAuditEvent::RECENT_LIMIT + 2).times do |i|
      McpAuditEvent.record!(context: @context, tool_name: "t", outcome: "ok").update!(created_at: i.minutes.ago)
    end

    recent = McpAuditEvent.recent.to_a
    assert_equal McpAuditEvent::RECENT_LIMIT, recent.size
    assert_equal recent.sort_by(&:created_at).reverse, recent
  end

  test "client_names_for falls back to nothing for an unregistered client" do
    event = McpAuditEvent.record!(context: @context, tool_name: "t", outcome: "ok")

    assert_equal({}, McpAuditEvent.client_names_for([ event ]))
  end
end
