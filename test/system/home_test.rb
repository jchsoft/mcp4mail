require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "visitor sees the hero with both calls to action" do
    visit root_url

    assert_selector "h1", text: "Your mail, readable by your AI."

    within_hero do
      assert_text "Open source · MIT · free to self‑host"
      assert_text "Works with Claude Desktop and Cowork"
      assert_text "Your mail is not on Gmail?"
      assert_link "Connect a mailbox", href: new_registration_path
      assert_link "Source on GitHub", href: "https://github.com/jchsoft/mcp4mail"
    end
  end

  test "the provider strip takes a visitor to their provider's guide" do
    visit root_url

    click_link "WEDOS"

    assert_current_path guide_path("wedos")
    within("header") { click_link "Guides" }
    assert_current_path guides_path
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

  test "the answer mock reads as a chat: named speakers, an earlier exchange, a composer" do
    visit root_url

    within "[aria-label='Example question and answer']" do
      assert_text "Chat with your AI"
      assert_text "mcp4mail connected"
      assert_selector "span", text: "You", exact_text: true
      assert_selector "span", text: "AI assistant", exact_text: true
      # The earlier exchange and the composer are scenery, kept out of the
      # accessibility tree.
      assert_selector "[aria-hidden=true]", text: "Has the parcel from the e‑shop shipped yet?", visible: :all
      assert_selector "[aria-hidden=true]", text: "Ask about your mail…", visible: :all
    end
    screenshot!("landing-hero-en")

    visit root_url(locale: :cs)
    within("[aria-label='Ukázka otázky a odpovědi']") { assert_text "Chat s vaší AI" }
    screenshot!("landing-hero-cs")
  end

  test "switching to Czech and back changes the page and survives a reload" do
    visit root_url
    assert_selector "html[lang=en]"

    within("header") { click_link "CS" }
    assert_selector "html[lang=cs]"
    assert_selector "h1", text: "Vaše pošta,"

    visit root_url
    assert_selector "html[lang=cs]"

    within("header") { click_link "EN" }
    assert_selector "html[lang=en]"
    assert_selector "h1", text: "Your mail,"

    visit root_url
    assert_selector "html[lang=en]"
  end

  test "the closing and header calls to action follow a signed-in visitor to their mailboxes" do
    visit new_session_url
    fill_in placeholder: "Enter your email address", with: users(:one).email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    within("main section:last-of-type") { assert_link "Connect a mailbox", href: mail_accounts_path }
    within("header") { assert_link "Connect a mailbox", href: mail_accounts_path }
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
    # scope to the section rather than the whole page. The hero is the first of
    # several sections now, hence :first-of-type.
    def within_hero(&block)
      within("main section:first-of-type", &block)
    end
end
