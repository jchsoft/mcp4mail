require "application_system_test_case"

class LandingHowTest < ApplicationSystemTestCase
  INK = "rgb(31, 36, 48)".freeze
  WHITE = "rgb(255, 255, 255)".freeze
  BRAND = "rgb(242, 107, 29)".freeze
  HIGHLIGHT = "rgb(255, 209, 102)".freeze
  GREEN = "rgb(31, 138, 112)".freeze
  CHIP_TINT = "rgb(241, 235, 225)".freeze
  LINE = "rgb(235, 228, 216)".freeze

  test "the section renders its three steps and the client row from the locale, in either language" do
    visit root_url

    within "#how" do
      assert_selector "h2", text: "Three steps. Nothing to install."
      assert_selector "ol > li", count: 3
      assert_selector "h3", text: "Add a mailbox"
      assert_selector "strong", text: "app password"
      assert_selector "span", text: "Claude Desktop"
      assert_selector "span", text: "anything with MCP"
    end

    visit root_url(locale: :cs)

    within "#how" do
      assert_selector "h2", text: "Tři kroky. Žádná instalace."
      assert_selector "ol > li", count: 3
      assert_selector "h3", text: "Přidejte schránku"
      assert_selector "strong", text: "heslo aplikace"
      assert_selector "span", text: "cokoli s MCP"
    end
  end

  test "the connector chip prints the address the connector itself answers on" do
    visit root_url

    assert_selector "#how code", text: Hitch.configuration.resource_uri.sub(%r{\Ahttps?://}, "")

    chip = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector("#how code"));
        return { background: style.backgroundColor, color: style.color, radius: style.borderTopLeftRadius };
      })()
    JS

    # The design styles only the dark-panel chip; on the light ground it takes
    # the same surface-hover tint the rest of the page uses.
    assert_equal CHIP_TINT, chip["background"]
    assert_equal INK, chip["color"]
    assert_equal "6px", chip["radius"]
  end

  test "each numeral carries the tint of the reference file" do
    visit root_url

    badges = page.evaluate_script(<<~JS)
      (() => Array.from(document.querySelectorAll("#how ol > li > span")).map((badge) => {
        const style = getComputedStyle(badge);
        return {
          background: style.backgroundColor,
          color: style.color,
          size: style.width,
          hidden: badge.getAttribute("aria-hidden"),
          text: badge.textContent.trim()
        };
      }))()
    JS

    assert_equal %w[1 2 3], badges.map { |badge| badge["text"] }
    assert_equal [BRAND, HIGHLIGHT, GREEN], badges.map { |badge| badge["background"] }
    assert_equal [INK, INK, WHITE], badges.map { |badge| badge["color"] }
    assert_equal ["52px"] * 3, badges.map { |badge| badge["size"] }
    # The <ol> already tells a screen reader "2 of 3"; the drawn numeral would
    # only say it a second time.
    assert_equal ["true"] * 3, badges.map { |badge| badge["hidden"] }
  end

  test "the steps keep their list semantics even with the markers drawn by hand" do
    visit root_url

    list = page.evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector("#how ol");
        return {
          tag: list.tagName,
          role: list.getAttribute("role"),
          style: getComputedStyle(list).listStyleType
        };
      })()
    JS

    assert_equal "OL", list["tag"]
    # list-style:none drops an <ol> out of the accessibility tree in Safari and
    # VoiceOver; role="list" is what puts it back.
    assert_equal "list", list["role"]
    assert_equal "none", list["style"]
  end

  test "the client names are chips, not links" do
    visit root_url

    within "#how" do
      assert_no_selector "a"
    end

    chip = page.evaluate_script(<<~JS)
      (() => {
        const chips = document.querySelectorAll("#how > div span");
        const chip = chips[chips.length - 1];
        const style = getComputedStyle(chip);
        return {
          background: style.backgroundColor,
          border: style.borderTopColor,
          radius: parseFloat(style.borderTopLeftRadius),
          height: chip.getBoundingClientRect().height
        };
      })()
    JS

    assert_equal WHITE, chip["background"]
    assert_equal LINE, chip["border"]
    # A pill, not a rounded rectangle. The radius is asked of the box rather
    # than compared to a literal: rounded-full computes to an effectively
    # infinite length, which the browser prints as 3.4e38px.
    assert_operator chip["radius"], :>=, chip["height"] / 2
  end

  test "the steps stack and the chip row wraps cleanly at 375px" do
    resize_window_to 375, 900
    visit root_url

    layout = page.evaluate_script(<<~JS)
      (() => {
        const section = document.querySelector("#how");
        const list = section.querySelector("ol");
        const row = section.lastElementChild;
        const chips = Array.from(row.querySelectorAll("span"));
        const viewport = document.documentElement.clientWidth;
        return {
          columns: getComputedStyle(list).gridTemplateColumns.split(" ").length,
          rows: new Set(chips.map((chip) => Math.round(chip.getBoundingClientRect().top))).size,
          overflowing: chips.filter((chip) => {
            const box = chip.getBoundingClientRect();
            return box.left < 0 || box.right > viewport;
          }).length,
          scrollable: document.documentElement.scrollWidth > viewport
        };
      })()
    JS

    assert_equal 1, layout["columns"], "the steps should stack into one column at 375px"
    assert_operator layout["rows"], :>, 1, "the chip row should wrap rather than run off the screen"
    assert_equal 0, layout["overflowing"]
    assert_equal false, layout["scrollable"]
  ensure
    resize_window_to 1400, 1400
  end

  private
    def resize_window_to(width, height)
      page.current_window.resize_to(width, height)
    end
end
