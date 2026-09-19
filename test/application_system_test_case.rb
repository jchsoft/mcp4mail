require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # One process, however many tests there are. Minitest parallelises a file set
  # over 50 tests by default, and the accessibility pass of task #12708 took the
  # system suite past that line: eight headless Firefoxes on one machine started
  # dropping clicks, so sign-ins landed back on /session/new and anchor links
  # left the URL unchanged, in tests that had nothing to do with the change.
  # The unit suite in test/test_helper.rb keeps its workers; only browsers are
  # too heavy to run eight at a time.
  parallelize(workers: 1)

  # Pages follow Accept-Language, so pin the browser to English instead of the machine's locale.
  driven_by :selenium, using: :headless_firefox, screen_size: [1400, 1400] do |options|
    options.add_preference("intl.accept_languages", "en")
  end
end
