require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Pages follow Accept-Language, so pin the browser to English instead of the machine's locale.
  driven_by :selenium, using: :headless_firefox, screen_size: [1400, 1400] do |options|
    options.add_preference("intl.accept_languages", "en")
  end
end
