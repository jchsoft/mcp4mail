require "application_system_test_case"

class LandingHeaderTest < ApplicationSystemTestCase
  test "the header wraps cleanly on a 375px phone, with no horizontal scroll" do
    page.driver.browser.manage.window.resize_to(375, 800)
    visit root_url

    assert_selector "header a", text: "mcp4mail"
    assert_link "Security"
    assert_link "Connect a mailbox"

    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator overflow, :<=, 0, "the header must not push the page into horizontal scrolling at 375px"

    # Wrapped, not squeezed: the nav row sits below the brand rather than beside it.
    brand_bottom = element_box("header > a")["bottom"]
    nav_top = element_box("header nav")["top"]
    assert_operator nav_top, :>=, brand_bottom - 1, "expected the nav links to wrap onto their own line"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "switching the language in the header sticks across a reload" do
    visit root_url
    assert_selector "html[lang=en]"

    # The footer carries the same switcher, so aim at the header's copy.
    within("header") { click_link "CS" }
    assert_selector "html[lang=cs]"
    assert_link "Bezpečnost"

    visit root_url
    assert_selector "html[lang=cs]"
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
