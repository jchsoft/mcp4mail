require "application_system_test_case"

# The whole landing page at the three widths of task #12707, in both languages.
# The section tests each check their own block; this one checks the page as one
# thing, which is where the problems nobody owns turn up.
#
# The page is loaded inside an iframe of the exact width rather than by resizing
# the browser window. Headless Firefox will not give us a window narrower than
# about 500 CSS px, so a window-resized "375px" test is really a 500px test — the
# tightest case, the one the Czech copy breaks first, would never be measured. An
# iframe is its own viewport, so vw units, clamp() and media queries all resolve
# against its width, and 375 means 375.
class LandingResponsiveTest < ApplicationSystemTestCase
  PHONE = 375
  TABLET = 768
  LAPTOP = 1440
  WIDTHS = [PHONE, TABLET, LAPTOP].freeze
  LOCALES = [:en, :cs].freeze

  test "no width in either language pushes the page into horizontal scrolling" do
    each_viewport do |width, locale|
      overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_operator overflow, :<=, 0,
                      "#{locale} at #{width}px scrolls sideways by #{overflow}px, past: #{overflowing_elements.join(" | ")}"
    end
  end

  test "the hero stacks copy above the sample answer on a phone" do
    each_viewport(widths: [PHONE]) do |_width, locale|
      # ":last-child", not "div:last-child": the mock became a <figure> on the
      # accessibility pass of task #12708, so the hero's two columns are no
      # longer the same element.
      assert_operator box("main > section:first-of-type > :first-child")["top"],
                      :<,
                      box("main > section:first-of-type > :last-child")["top"],
                      "#{locale}: the hero mock must follow the copy, not lead it"
    end
  end

  # Three cards in two columns leave the third alone in a row of its own, which
  # reads as a mistake. One column or three, never two.
  test "the three-item grids are one column or three, never an orphan" do
    { PHONE => [1, 1, 1], TABLET => [1, 1, 1], LAPTOP => [3] }.each do |width, rows|
      each_viewport(widths: [width]) do |_width, locale|
        assert_equal rows, row_sizes("#why figure"), "#{locale} at #{width}px: why cards"
        assert_equal rows, row_sizes("#how ol > li"), "#{locale} at #{width}px: how steps"
      end
    end
  end

  # The design draws the four guarantees as one row at its reference width.
  test "the security panel holds four columns at the reference width" do
    { PHONE => [1, 1, 1, 1], TABLET => [2, 2], LAPTOP => [4] }.each do |width, rows|
      each_viewport(widths: [width]) do |_width, locale|
        assert_equal rows, row_sizes("#security div.grid > div"), "#{locale} at #{width}px: security points"
      end
    end
  end

  # The header may wrap — it has to at 375 — but it wraps in whole groups. The
  # switcher and the call to action are one group and share a line at every width.
  test "the header wraps in whole groups, never leaving the call to action alone" do
    each_viewport do |width, locale|
      assert_in_delta box("header span[role=group]")["top"],
                      box("header > div > a:last-child")["top"],
                      24,
                      "#{locale} at #{width}px: the switcher and the call to action must stay on one line"
    end
  end

  # Below lg the header and footer links are tap targets on a touch screen.
  test "header and footer tap targets clear 44px at touch widths" do
    each_viewport(widths: [PHONE, TABLET]) do |width, locale|
      assert_empty small_targets, "#{locale} at #{width}px has tap targets under 44px"
    end
  end

  test "the page is captured at every width in both languages" do
    FileUtils.mkdir_p(screenshot_dir)

    WIDTHS.product(LOCALES).each do |width, locale|
      open_viewport(width, locale)

      # Firefox clips an element capture to the window, so the window has to be
      # as tall as the frame for the screenshot to hold the whole page.
      page.driver.browser.manage.window.resize_to([width + 80, 560].max,
                                                  evaluate_script("document.getElementById('viewport').offsetHeight") + 40)

      path = screenshot_dir.join("landing-#{locale}-#{width}.png")
      File.binwrite(path, find("#viewport").native.screenshot_as(:png))
      assert_operator File.size(path), :>, 10_000, "#{path} looks empty"
    end
  end

  private
    def screenshot_dir
      Rails.root.join("tmp/responsive")
    end

    # Loads the page in an iframe of the given width and yields inside it, once
    # per width and language.
    def each_viewport(widths: WIDTHS, locales: LOCALES)
      widths.each do |width|
        locales.each do |locale|
          open_viewport(width, locale)
          within_frame(find("#viewport")) { yield width, locale }
        end
      end
    end

    def open_viewport(width, locale)
      # The window only has to be wide enough to hold the frame; the frame is
      # what the page sees.
      page.driver.browser.manage.window.resize_to([width + 80, 560].max, 1000)
      visit root_url(locale: locale)

      page.execute_script(<<~JS, root_url(locale: locale), width)
        const [url, width] = arguments;
        document.body.replaceChildren();
        document.body.style.margin = "0";
        const frame = document.createElement("iframe");
        frame.id = "viewport";
        frame.style.cssText = `width:${width}px;height:900px;border:0;display:block;color-scheme:light`;
        frame.src = url;
        document.body.appendChild(frame);
      JS

      within_frame(find("#viewport")) { assert_selector "h1" }

      # Grown to its content, the frame never scrolls, so no scrollbar eats into
      # the width we are measuring and the screenshot holds the whole page.
      page.execute_script(<<~JS)
        const frame = document.getElementById("viewport");
        frame.style.height = `${frame.contentDocument.documentElement.scrollHeight}px`;
      JS
    end

    def box(selector)
      evaluate_script(<<~JS)
        (() => {
          const rect = document.querySelector("#{selector}").getBoundingClientRect();
          return { top: rect.top, left: rect.left, width: rect.width, height: rect.height };
        })()
      JS
    end

    # Everything whose box reaches past either edge of the viewport, named well
    # enough to find in the markup.
    def overflowing_elements
      evaluate_script(<<~JS)
        (() => {
          const viewport = document.documentElement.clientWidth;
          return [...document.querySelectorAll("body *")].filter(element => {
            const rect = element.getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) return false;
            return rect.right > viewport + 1 || rect.left < -1;
          }).map(element => `${element.tagName}.${element.className} "${element.textContent.trim().slice(0, 30)}"`);
        })()
      JS
    end

    # How many items sit in each row of a grid, top to bottom.
    def row_sizes(selector)
      evaluate_script(<<~JS)
        (() => {
          const rows = new Map();
          document.querySelectorAll("#{selector}").forEach(element => {
            const top = Math.round(element.getBoundingClientRect().top);
            rows.set(top, (rows.get(top) || 0) + 1);
          });
          return [...rows.entries()].sort((a, b) => a[0] - b[0]).map(entry => entry[1]);
        })()
      JS
    end

    # Header and footer chrome only: links inside prose are words in a sentence,
    # not buttons, and inflating them would break the line they sit in.
    def small_targets
      evaluate_script(<<~JS)
        (() => {
          return [...document.querySelectorAll("header a, footer a, summary")].filter(element => {
            const rect = element.getBoundingClientRect();
            return rect.width > 0 && (rect.height < 44 || rect.width < 44);
          }).map(element => `"${element.textContent.trim().slice(0, 20)}" ${Math.round(element.getBoundingClientRect().width)}x${Math.round(element.getBoundingClientRect().height)}`);
        })()
      JS
    end
end
