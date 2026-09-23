require "application_system_test_case"

class LandingWhyTest < ApplicationSystemTestCase
  test "the header's anchor jumps to the section" do
    visit root_url

    click_link "Why"

    assert_current_path("#{root_url}#why", url: true)
    assert_selector "section#why blockquote", count: 3
    screenshot!("landing-why-en")

    visit root_url(locale: :cs)
    click_link "K čemu"
    screenshot!("landing-why-cs")
  end

  test "the cards stack on a phone and sit side by side on a desktop" do
    resize_to(375, 800)
    visit root_url

    assert_equal 1, card_columns, "expected one column at 375px"
    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    assert_operator overflow, :<=, 0, "the cards must not push the page into horizontal scrolling at 375px"

    resize_to(1440, 900)
    assert_equal 3, card_columns, "expected three across at 1440px"
  ensure
    resize_to(1400, 1400)
  end

  private
    def resize_to(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end

    # The grid is breakpoint-free, so count the distinct left edges the cards
    # actually land on rather than asserting a media query.
    def card_columns
      page.evaluate_script(<<~JS)
        (() => {
          const lefts = [...document.querySelectorAll("#why figure")]
            .map(el => Math.round(el.getBoundingClientRect().left));
          return new Set(lefts).size;
        })()
      JS
    end
end
