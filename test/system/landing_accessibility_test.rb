require "application_system_test_case"
require "axe/api/run"

# The accessibility pass of task #12708, kept as a test rather than as a one-off
# audit: every check below is one a future section could quietly break.
class LandingAccessibilityTest < ApplicationSystemTestCase
  LOCALES = %i[en cs].freeze

  # The tags axe should judge the page by. WCAG 2.1 AA is what the acceptance
  # criteria ask for; "best-practice" is deliberately left out, since it flags
  # opinions (a page-level region rule among them) rather than conformance.
  WCAG_AA = %i[wcag2a wcag2aa wcag21a wcag21aa].freeze

  # Anything axe rates serious or critical fails the build. minor/moderate
  # findings are reported in the failure message when something else fails, but
  # do not stop a merge on their own.
  BLOCKING_IMPACTS = %w[serious critical].freeze

  test "axe reports no serious or critical violations in either language" do
    LOCALES.each do |locale|
      visit root_url(locale: locale)

      audit = Axe::Core.new(page).call(Axe::API::Run.new.according_to(*WCAG_AA))
      blocking = audit.results.violations.select { |rule| BLOCKING_IMPACTS.include?(rule.impact.to_s) }

      assert_empty blocking.map { |rule| "#{rule.impact} #{rule.id}: #{rule.help}" },
                   "#{locale}: axe found blocking violations\n#{audit.failure_message}"
    end
  end

  test "the skip link is the first tab stop and moves focus to main" do
    LOCALES.each do |locale|
      visit root_url(locale: locale)

      # Off-screen until focused: present in the DOM, outside the viewport.
      assert_selector "a.skip-link", visible: :all
      assert_operator page.evaluate_script("document.querySelector('.skip-link').getBoundingClientRect().right"), :<, 0,
                      "#{locale}: the skip link must sit off-screen until it takes focus"

      # One Tab from the document body lands on it, ahead of the whole header.
      page.driver.browser.action.send_keys(:tab).perform
      assert_equal "skip-link", focused_attribute("className"),
                   "#{locale}: the skip link must be the first tab stop"
      assert_operator page.evaluate_script("document.querySelector('.skip-link').getBoundingClientRect().left"), :>=, 0,
                      "#{locale}: the skip link must be on-screen once focused"

      # assert_selector rather than a straight read of document.activeElement:
      # the browser moves focus a tick after the fragment navigation, and the
      # read would otherwise catch the link still holding it.
      page.driver.browser.action.send_keys(:enter).perform
      assert_selector "main#main:focus", visible: :all
    end
  end

  test "the heading outline runs h1 to h3 with no level skipped" do
    LOCALES.each do |locale|
      visit root_url(locale: locale)

      levels = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map(h => Number(h.tagName[1]))
      JS

      assert_equal 1, levels.count(1), "#{locale}: the page needs exactly one h1"
      assert_equal 1, levels.first, "#{locale}: the first heading on the page must be the h1"
      assert_equal 3, levels.max, "#{locale}: the outline stops at h3"

      levels.each_cons(2) do |previous, current|
        assert_operator current, :<=, previous + 1, "#{locale}: h#{previous} is followed by h#{current}, skipping a level"
      end
    end
  end

  test "every section of the page is named by a heading" do
    visit root_url

    %w[why how security built faq].each do |id|
      assert_selector "##{id} h2", count: 1, visible: :all
    end
  end

  test "the landmarks are present once each" do
    LOCALES.each do |locale|
      visit root_url(locale: locale)

      { "header" => 1, "main" => 1, "footer" => 1, "nav" => 1 }.each do |landmark, expected|
        assert_equal expected, page.evaluate_script("document.querySelectorAll('#{landmark}').length"),
                     "#{locale}: expected exactly #{expected} <#{landmark}>"
      end
    end
  end

  test "the lang attribute follows the locale" do
    LOCALES.each do |locale|
      visit root_url(locale: locale)
      assert_equal locale.to_s, page.evaluate_script("document.documentElement.lang")
    end
  end

  test "the hero mock is announced as an example rather than read as the visitor's own mail" do
    visit root_url

    role, name = page.evaluate_script(<<~JS)
      (() => {
        const fig = document.querySelector('#main figure[aria-label]');
        return [fig.tagName.toLowerCase(), fig.getAttribute('aria-label')];
      })()
    JS

    # aria-label names an element only when its role takes a name; on the plain
    # <div> this used to be, it was dropped and never announced.
    assert_equal "figure", role
    assert_includes name.downcase, "example"
  end

  test "decorative marks are hidden from assistive technology" do
    visit root_url

    decorations = page.evaluate_script(<<~JS)
      ['header a span', '#how ol > li > span', '#faq .faq-mark', '#built a span']
        .flatMap(s => Array.from(document.querySelectorAll(s)))
        .map(el => [el.className, el.getAttribute('aria-hidden')])
    JS

    assert decorations.any?, "expected to find the page's decorative marks"
    decorations.each do |class_name, hidden|
      assert_equal "true", hidden, "#{class_name} is decorative and must carry aria-hidden"
    end
  end

  # The ring has to carry on the cream page, on the white cards and on the dark
  # Security panel. The brand orange alone does not: 2.87:1 on cream against the
  # 3:1 WCAG 1.4.11 asks, which is why it is paired with an ink outline.
  test "the focus ring is drawn in both of its colours, on the dark panel and on the light page" do
    visit root_url

    { "#security a" => "the dark security panel", "header nav a" => "the light page" }.each do |selector, where|
      ring = page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector("#{selector}");
          el.focus();
          const s = getComputedStyle(el);
          return [s.outlineStyle, s.outlineWidth, s.outlineColor, s.outlineOffset, s.boxShadow];
        })()
      JS

      assert_equal "solid", ring[0], where
      assert_equal "3px", ring[1], where
      assert_equal "rgb(31, 36, 48)", ring[2], "#{where}: the outer half of the ring is ink"
      assert_equal "3px", ring[3], where
      assert_includes ring[4], "rgb(242, 107, 29)", "#{where}: the inner half of the ring is brand orange"
    end
  end

  # Read out of the stylesheet rather than by emulating the preference: Firefox
  # takes prefers-reduced-motion from a profile preference the running session
  # cannot flip, so emulating it would only ever skip.
  test "reduced motion turns off both of the page's global animations" do
    visit root_url

    # Tailwind wraps the base layer in @layer, so the media rule is not a
    # top-level rule of the sheet — flatten the grouping rules on the way down.
    declarations = page.evaluate_script(<<~JS)
      Array.from(document.styleSheets)
        .flatMap(sheet => Array.from(sheet.cssRules))
        .flatMap(function flatten(rule) {
          if (rule.cssRules && !(rule instanceof CSSMediaRule)) return Array.from(rule.cssRules).flatMap(flatten);
          return [rule];
        })
        .filter(rule => rule instanceof CSSMediaRule && rule.conditionText.includes('prefers-reduced-motion'))
        .flatMap(rule => Array.from(rule.cssRules))
        .map(rule => [rule.selectorText, rule.style.cssText])
    JS

    assert declarations.any? { |selector, css| selector == "html" && css.include?("scroll-behavior: auto") },
           "the header anchors must jump rather than glide under reduced motion, got #{declarations.inspect}"
    assert declarations.any? { |selector, css| selector == ".faq-mark" && css.match?(/transition(-duration)?: (none|0s)/) },
           "the FAQ marker must not rotate under reduced motion, got #{declarations.inspect}"
  end

  test "no link leans on its surroundings to say where it goes" do
    LOCALES.each do |locale|
      visit root_url(locale: locale)

      vague = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('a'))
             .map(a => (a.innerText || a.textContent || '').trim().toLowerCase().replace(/[.…]+$/, ''))
             .filter(t => ['here', 'click here', 'read more', 'more', 'link', 'tady', 'zde', 'více', 'vice', 'sem'].includes(t))
      JS

      assert_empty vague, "#{locale}: these links do not say where they go out of context"
    end
  end

  private
    def focused_attribute(property)
      page.evaluate_script("document.activeElement.#{property}")
    end
end
