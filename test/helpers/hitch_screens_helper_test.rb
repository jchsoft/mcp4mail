require "test_helper"

class HitchScreensHelperTest < ActionView::TestCase
  test "translates each fixed activation alert the gem sends" do
    HitchScreensHelper::HITCH_ACTIVATION_ALERTS.each do |english, key|
      assert_equal I18n.t("hitch.activation_alerts.#{key}"), hitch_activation_alert(english)
    end
  end

  test "an alert the gem added later passes through untranslated" do
    assert_equal "A brand new alert.", hitch_activation_alert("A brand new alert.")
  end

  test "describes a known scope in words" do
    assert_equal I18n.t("hitch.scopes.mcp"), hitch_scope_description("mcp")
  end

  test "an unknown scope has no description" do
    assert_nil hitch_scope_description("unheard_of")
  end

  test "a scope that is not a plain token is never looked up" do
    assert_nil hitch_scope_description("mcp.read")
  end
end
