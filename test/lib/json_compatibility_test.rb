require "test_helper"

# Guards the `gem "json", "< 3"` pin in the Gemfile: with json 3.0 and Rails 8.1.3 this raised ArgumentError
# and took the Solid Queue supervisor's workers down in production.
class JsonCompatibilityTest < ActiveSupport::TestCase
  test "ActiveSupport::JSON.decode works with the bundled json gem" do
    assert_equal({ "a" => 1 }, ActiveSupport::JSON.decode('{"a":1}'))
  end
end
