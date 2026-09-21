require "test_helper"

class McpClientSightingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  Context = Struct.new(:principal, :client_id, :remote_ip, keyword_init: true)

  setup do
    @user = users(:one)
    @account = mail_accounts(:work)
  end

  test "the first call from a client records it and enqueues one alert" do
    assert_enqueued_emails 1 do
      McpClientSighting.record!(context: context, mail_account_id: @account.id)
    end

    sighting = McpClientSighting.sole
    assert_equal [ @user, @account, "claude", "127.0.0.1" ],
      [ sighting.user, sighting.mail_account, sighting.client_id, sighting.remote_ip ]
    assert_not_nil sighting.first_seen_at
  end

  test "a repeat call from the same client and address changes nothing" do
    McpClientSighting.record!(context: context, mail_account_id: @account.id)
    first_seen_at = McpClientSighting.sole.first_seen_at

    travel 1.hour do
      assert_no_enqueued_emails do
        McpClientSighting.record!(context: context, mail_account_id: @account.id)
      end
    end

    assert_equal first_seen_at, McpClientSighting.sole.first_seen_at
  end

  test "a known client from a new address is recorded without an alert" do
    McpClientSighting.record!(context: context, mail_account_id: @account.id)

    assert_no_enqueued_emails do
      McpClientSighting.record!(context: context(remote_ip: "127.0.0.2"), mail_account_id: @account.id)
    end

    assert_equal %w[127.0.0.1 127.0.0.2], McpClientSighting.order(:id).pluck(:remote_ip)
  end

  test "a call without a known address is recorded once" do
    McpClientSighting.record!(context: context(remote_ip: nil), mail_account_id: @account.id)

    assert_no_enqueued_emails do
      McpClientSighting.record!(context: context(remote_ip: nil), mail_account_id: @account.id)
    end

    assert_equal 1, McpClientSighting.count
  end

  test "a second client on the same mailbox gets its own alert" do
    McpClientSighting.record!(context: context, mail_account_id: @account.id)

    assert_enqueued_emails 1 do
      McpClientSighting.record!(context: context(client_id: "cursor"), mail_account_id: @account.id)
    end
  end

  test "the client name falls back to its id when the registration is gone" do
    sighting = McpClientSighting.new(client_id: "gone-client")

    assert_equal "gone-client", sighting.client_name
  end

  private
    def context(client_id: "claude", remote_ip: "127.0.0.1")
      Context.new(principal: @user, client_id:, remote_ip:)
    end
end
