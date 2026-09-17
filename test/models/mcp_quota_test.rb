require "test_helper"

class McpQuotaTest < ActiveSupport::TestCase
  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @quota = McpQuota.new("test", to: 2, within: 1.minute)
  end

  teardown do
    McpQuota.store_override = nil
  end

  test "admits up to the limit within a window, then refuses" do
    assert @quota.admit?(users(:one))
    assert @quota.admit?(users(:one))
    assert_not @quota.admit?(users(:one))
    assert @quota.admit?(users(:two)), "another subject has its own window"
  end

  test "a new window starts the count again" do
    3.times { @quota.admit?(users(:one)) }

    travel 1.minute do
      assert @quota.admit?(users(:one))
    end
  end

  test "exhausted? reads the count without consuming it" do
    assert_not @quota.exhausted?(users(:one))
    @quota.consume(users(:one), 2)

    assert @quota.exhausted?(users(:one))
    assert_equal 2, @quota.consume(users(:one), 0)
  end

  test "a store that cannot count admits everything" do
    McpQuota.store_override = ActiveSupport::Cache::NullStore.new

    5.times { assert @quota.admit?(users(:one)) }
    assert_not @quota.exhausted?(users(:one))
  end
end
