require "test_helper"
require "hitch/mcp/test_helper"

class McpTools::IndexFreshnessTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @account = mail_accounts(:work)
    @token = mint_mcp_token(principal: users(:one))
  end

  teardown do
    McpQuota.store_override = nil
  end

  test "an account with no synced folder has a null indexed_at and no sync_errors" do
    @account.mail_folders.create!(name: "INBOX")

    summary = list_summary

    assert summary.key?("indexed_at")
    assert_nil summary["indexed_at"]
    assert_not summary.key?("sync_errors")
  end

  test "a freshly synced account reports when it was indexed" do
    synced_at = Time.utc(2026, 10, 5, 10, 0, 0)
    @account.mail_folders.create!(name: "INBOX", last_synced_at: synced_at)

    assert_equal "2026-10-05T10:00:00Z", Time.iso8601(list_summary["indexed_at"]).utc.iso8601
    assert_equal list_summary["indexed_at"], get_summary["indexed_at"]
  end

  test "indexed_at is the oldest folder sync" do
    @account.mail_folders.create!(name: "INBOX", last_synced_at: Time.utc(2026, 10, 5, 10, 0, 0))
    @account.mail_folders.create!(name: "Sent", last_synced_at: Time.utc(2026, 10, 5, 8, 0, 0))

    assert_equal "2026-10-05T08:00:00Z", Time.iso8601(get_summary["indexed_at"]).utc.iso8601
  end

  test "a folder with a last_error is listed in sync_errors" do
    @account.mail_folders.create!(name: "INBOX", last_synced_at: Time.current)
    @account.mail_folders.create!(name: "Archive", last_error: "timeout")

    assert_equal [ { "folder" => "Archive", "error" => "timeout" } ], get_summary["sync_errors"]
    assert_equal [ { "folder" => "Archive", "error" => "timeout" } ], list_summary["sync_errors"]
  end

  private
    def list_summary = JSON.parse(call_tool("list_mail_accounts").dig("content", 0, "text")).sole

    def get_summary = JSON.parse(call_tool("get_mail_account", account_id: @account.id).dig("content", 0, "text"))

    def call_tool(name, **arguments)
      post_mcp(method: "tools/call", token: @token, params: { name:, arguments: })
      assert_response :success
      response.parsed_body.fetch("result")
    end
end
