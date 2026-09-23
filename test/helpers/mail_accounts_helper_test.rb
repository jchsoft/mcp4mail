require "test_helper"

class MailAccountsHelperTest < ActionView::TestCase
  test "the two answers a person reads the activity list for are coloured" do
    assert_equal :ok, outcome_badge_variant("ok")
    assert_equal :ok, outcome_badge_variant("sent")
    assert_equal :denied, outcome_badge_variant("denied")
    assert_equal :denied, outcome_badge_variant("error")
  end

  test "everything in between stays neutral" do
    (McpAuditEvent::OUTCOMES - %w[ok sent denied error]).each do |outcome|
      assert_equal :neutral, outcome_badge_variant(outcome), outcome
    end
  end

  test "every outcome an event can hold has a variant" do
    McpAuditEvent::OUTCOMES.each { |outcome| assert_includes %i[ok denied neutral], outcome_badge_variant(outcome) }
  end
end
