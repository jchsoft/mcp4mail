require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "visitor sees the hero with both calls to action" do
    visit root_url

    assert_selector "h1", text: "Your mail, readable by your AI."

    within_hero do
      assert_text "Open source · MIT · free to self‑host"
      assert_text "Works with Claude Desktop and Cowork"
      assert_link "Connect a mailbox", href: new_registration_path
      assert_link "Source on GitHub", href: "https://github.com/jchsoft/mcp4mail"
    end
  end

  test "the primary call to action points a signed-in visitor at their mailboxes" do
    visit new_session_url
    fill_in placeholder: "Enter your email address", with: users(:one).email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    within_hero { assert_link "Connect a mailbox", href: mail_accounts_path }
  end

  test "the answer mock renders its items from the locale, in either language" do
    visit root_url

    within "[aria-label='Example question and answer']" do
      assert_text "Read from your mailbox · 4 messages"
      assert_selector "li", count: 3
      assert_selector "li strong", text: "January"
      assert_text "Illustrative. Nothing in the mailbox changed"
    end

    visit root_url(locale: :cs)

    within "[aria-label='Ukázka otázky a odpovědi']" do
      assert_selector "li", count: 3
      assert_selector "li strong", text: "Srpen"
      assert_text "Ilustrační ukázka."
    end
  end

  test "the highlighted word sits on a gradient behind its descenders" do
    visit root_url

    assert_selector "h1 span", text: "readable"
    assert_includes page.evaluate_script(<<~JS), "linear-gradient"
      getComputedStyle(document.querySelector("h1 span")).backgroundImage
    JS
  end

  test "the primary call to action keeps its ink label on the orange pill" do
    visit root_url

    styles = page.evaluate_script(<<~JS)
      (() => {
        const link = Array.from(document.querySelectorAll("main section a"))
          .find(a => a.textContent.trim() === "Connect a mailbox");
        const style = getComputedStyle(link);
        return { color: style.color, background: style.backgroundColor };
      })()
    JS

    assert_equal "rgb(31, 36, 48)", styles["color"]
    assert_equal "rgb(242, 107, 29)", styles["background"]
  end

  private
    # The header carries a "Connect a mailbox" link of its own, so hero assertions
    # scope to the section rather than the whole page. The hero is the first
    # section of the page and the landing has more of them below it, so name it
    # by position rather than matching every section.
    def within_hero(&block)
      within("main section:first-of-type", &block)
    end
end
