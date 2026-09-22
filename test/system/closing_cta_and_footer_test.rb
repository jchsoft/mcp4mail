require "application_system_test_case"

class ClosingCtaAndFooterTest < ApplicationSystemTestCase
  # The last section of the landing page, ahead of the footer.
  CLOSING_CTA = "main section:last-of-type".freeze

  # What the two blocks contain, and where their links point, is covered without
  # a browser in test/controllers/marketing_footer_test.rb. What is left here is
  # what only a browser can answer: that the footer switcher actually switches,
  # and that both blocks wrap instead of overflowing on a phone.

  test "the footer's external links are reachable and land on the right page, in both locales" do
    [ :en, :cs ].each do |locale|
      visit root_url(locale: locale)
      within("footer") { click_link I18n.t("pages.home.footer.self_hosting", locale: locale) }
      assert_equal "https://github.com/jchsoft/mcp4mail/blob/main/docs/self-hosting.md", page.current_url

      visit root_url(locale: locale)
      within("footer") { click_link I18n.t("pages.home.footer.github", locale: locale) }
      assert_equal "https://github.com/jchsoft/mcp4mail", page.current_url
    end
  end

  test "the footer language switcher changes the language and marks the current one" do
    visit root_url

    within "footer" do
      assert_selector "a[aria-current=page]", text: "EN"
      click_link "CS"
    end

    assert_selector "html[lang=cs]"
    assert_selector "footer a[aria-current=page]", text: "CS"
    # The header's copy of the switcher agrees: both read the same I18n.locale.
    assert_selector "header a[aria-current=page]", text: "CS"
    assert_selector "main section:last-of-type h2", text: "Vaše schránka už čeká na první otázku."
  end

  test "the closing CTA and the footer wrap cleanly on a 375px phone" do
    page.driver.browser.manage.window.resize_to(375, 800)
    visit root_url

    assert_selector "footer a", text: "GitHub"

    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator overflow, :<=, 0, "the closing blocks must not push the page into horizontal scrolling at 375px"

    # Wrapped, not squeezed: the footer's last item sits below its first, and the
    # CTA buttons drop under the heading rather than sharing its line.
    assert_operator element_box("footer > :last-child")["top"], :>, element_box("footer > :first-child")["top"],
                    "expected the footer row to wrap onto several lines at 375px"

    assert_operator element_box("#{CLOSING_CTA} > div > div:last-child")["top"],
                    :>=, element_box("#{CLOSING_CTA} > div > div:first-child")["bottom"] - 1,
                    "expected the closing CTA buttons to wrap below the heading"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private
    def element_box(selector)
      page.evaluate_script(<<~JS)
        (() => {
          const rect = document.querySelector("#{selector}").getBoundingClientRect();
          return { top: rect.top, bottom: rect.bottom };
        })()
      JS
    end
end
