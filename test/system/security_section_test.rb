require "application_system_test_case"

class SecuritySectionTest < ApplicationSystemTestCase
  INK = "rgb(31, 36, 48)".freeze
  HIGHLIGHT = "rgb(255, 209, 102)".freeze
  BRAND = "rgb(242, 107, 29)".freeze
  CODE_CHIP = "rgb(52, 59, 74)".freeze

  test "the header's anchor jumps to the section" do
    visit root_url

    click_link "Security"

    assert_equal "#{root_url}#security", page.current_url
    assert_selector "section#security h3", count: 4
  end

  test "the panel renders its four guarantees from the locale, in either language" do
    visit root_url

    within "#security" do
      assert_selector "h2", text: "It reads. It never writes."
      assert_selector "span", text: /security/i
      assert_selector "h3", count: 4
      assert_selector "h3", text: "Read‑only, built in"
      assert_selector "code", text: "docker compose up"
      assert_link "Self‑hosting guide",
                  href: "https://github.com/jchsoft/mcp4mail/blob/main/docs/self-hosting.md"
    end
    screenshot!("landing-security-en")

    visit root_url(locale: :cs)

    within "#security" do
      assert_selector "h2", text: "Čte. Nikdy nepíše."
      assert_selector "h3", count: 4
      assert_selector "h3", text: "Jen čtení, zabudované"
      assert_link "Návod k self‑hostingu"
    end
    screenshot!("landing-security-cs")
  end

  test "the panel is the page's one dark surface, with a yellow kicker and link" do
    visit root_url

    styles = page.evaluate_script(<<~JS)
      (() => {
        const section = document.querySelector("#security");
        const panel = section.firstElementChild;
        const link = section.querySelector("a");
        return {
          panel: getComputedStyle(panel).backgroundColor,
          radius: getComputedStyle(panel).borderTopLeftRadius,
          kicker: getComputedStyle(section.querySelector("span")).color,
          link: getComputedStyle(link).color,
          chip: getComputedStyle(section.querySelector("code")).backgroundColor
        };
      })()
    JS

    assert_equal INK, styles["panel"]
    assert_equal "32px", styles["radius"]
    assert_equal HIGHLIGHT, styles["kicker"]
    assert_equal HIGHLIGHT, styles["link"]
    assert_equal CODE_CHIP, styles["chip"]
  end

  test "the in-panel link keeps a focus ring that reads against the dark surface" do
    visit root_url

    outline = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector("#security a");
        link.focus();
        const style = getComputedStyle(link);
        return {
          color: style.outlineColor,
          width: style.outlineWidth,
          style: style.outlineStyle,
          shadow: style.boxShadow
        };
      })()
    JS

    # Brand orange on ink is 5.1:1, past the 3:1 a focus indicator needs, so the
    # global ring is still not overridden inside the panel. Task #12708 found
    # the opposite problem — the same orange is 2.87:1 on the cream page — and
    # made the ring two-tone: an ink outline outside, the orange filling the
    # offset gap as a box-shadow. Here the ink half vanishes into the panel and
    # the orange half is what the visitor sees.
    assert_equal INK, outline["color"]
    assert_equal "solid", outline["style"]
    assert_equal "3px", outline["width"]
    assert_includes outline["shadow"], BRAND
  end

  test "the panel survives a 375px viewport without clipping its corners" do
    resize_window_to 375, 900
    visit root_url

    overflow = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("#security > div");
        const box = panel.getBoundingClientRect();
        return {
          left: Math.round(box.left),
          right: Math.round(document.documentElement.clientWidth - box.right),
          radius: getComputedStyle(panel).borderTopLeftRadius,
          columns: getComputedStyle(panel.lastElementChild).gridTemplateColumns.split(" ").length
        };
      })()
    JS

    assert_operator overflow["left"], :>=, 0
    assert_operator overflow["right"], :>=, 0
    assert_equal "32px", overflow["radius"]
    assert_equal 1, overflow["columns"], "the guarantees should stack into one column at 375px"
  ensure
    resize_window_to 1400, 1400
  end

  private
    def resize_window_to(width, height)
      page.current_window.resize_to(width, height)
    end
end
