require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "the connector address drops the scheme the visitor never types" do
    assert_equal Hitch.configuration.resource_uri.sub(%r{\Ahttps?://}, ""), connector_address
    refute_includes connector_address, "://"
  end

  test "it is the address the connector actually answers on" do
    assert Hitch.configuration.resource_uri.end_with?(connector_address)
  end
end
