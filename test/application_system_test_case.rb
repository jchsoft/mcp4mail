require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Rails runs test:prepare, and with it tailwindcss:build, only when no test
  # path is given, and bin/ci ends with assets:clobber. So after a CI run,
  # `bin/rails test test/system/some_test.rb` served every page unstyled and the
  # layout tests measured bare HTML (task #12862). Build the stylesheet here
  # whenever it is missing, so a single file runs against the real CSS.
  unless Rails.root.join("app/assets/builds/tailwind.css").exist?
    system("bin/rails", "tailwindcss:build", chdir: Rails.root.to_s, exception: true)
  end

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
