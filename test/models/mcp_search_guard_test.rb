require "test_helper"

class McpSearchGuardTest < ActiveSupport::TestCase
  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @account = mail_accounts(:work)
    @guard = McpSearchGuard.new(@account)
  end

  teardown do
    McpQuota.store_override = nil
  end

  test "caps the page size" do
    assert_equal McpSearchGuard::DEFAULT_PAGE_SIZE, McpSearchGuard.page_size(nil)
    assert_equal 1, McpSearchGuard.page_size(0)
    assert_equal 10, McpSearchGuard.page_size(10)
    assert_equal McpSearchGuard::MAX_PAGE_SIZE, McpSearchGuard.page_size(10_000)
  end

  test "refuses once the account's search count is used up" do
    McpSearchGuard::SEARCHES.consume(@account, McpSearchGuard::SEARCHES.to - 1)
    @guard.admit!

    error = assert_raises(McpSearchGuard::Exhausted) { @guard.admit! }
    assert_match "Too many searches", error.message
  end

  test "refuses once the account's row budget is used up, so paging cannot walk the mailbox" do
    @guard.admit!
    @guard.record_rows(McpSearchGuard::ROWS.to)

    error = assert_raises(McpSearchGuard::Exhausted) { @guard.admit! }
    assert_match "row budget", error.message
    assert McpSearchGuard.new(mail_accounts(:personal)).admit!.nil?, "other accounts keep their own budget"
  end
end
