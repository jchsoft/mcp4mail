require "test_helper"

# Screenshots
#
# One way to take one: `screenshot!("<area>-<screen>-<locale>[-<width>]")`, e.g.
# `screenshot!("landing-home-en")` or `screenshot!("landing-home-cs-375")`. The
# name is the whole identity of the file. No timestamps and no counters, so a
# capture from one run can be diffed against the same capture from the next; a
# second capture under the same name overwrites the first.
#
# Everything lands in tmp/screenshots (Capybara.save_path), which is also where
# Rails puts the implicit failure screenshots, so failures and deliberate
# captures share one directory and one CI artifact. tmp/responsive is gone.
#
# Widths below ~500 CSS px cannot be had by resizing headless Firefox, so the
# 375px captures in landing_responsive_test.rb load the page in an iframe of the
# exact width. That trick needs the test's own measuring helpers around it, so it
# stays in that test; it only borrows `screenshot_path` for where to write.

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Rails runs test:prepare, and with it tailwindcss:build, only when no test
  # path is given, and bin/ci ends with assets:clobber. So after a CI run,
  # `bin/rails test test/system/some_test.rb` served every page unstyled and the
  # layout tests measured bare HTML (task #12862). Build the stylesheet here
  # whenever it is missing, so a single file runs against the real CSS.
  unless Rails.root.join("app/assets/builds/tailwind.css").exist?
    system("bin/rails", "tailwindcss:build", chdir: Rails.root.to_s, exception: true)
  end

  Capybara.save_path = Rails.root.join("tmp/screenshots").to_s

  # Captures the current page under a deterministic name and returns the path.
  def screenshot!(name)
    path = screenshot_path(name)
    page.save_screenshot(path.to_s)
    path
  end

  def screenshot_path(name)
    FileUtils.mkdir_p(Capybara.save_path)
    Pathname.new(Capybara.save_path).join("#{name}.png")
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
