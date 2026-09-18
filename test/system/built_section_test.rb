require "application_system_test_case"

class BuiltSectionTest < ApplicationSystemTestCase
  GREEN = "rgb(31, 138, 112)".freeze
  LINE = "rgb(235, 228, 216)".freeze

  test "the section explains the workflow and renders its inline markup, in either language" do
    visit root_url

    within "#built" do
      assert_selector "span", text: /how this project is built/i
      assert_selector "h2", text: "Written by AI developers. Briefed by people."
      assert_link "mcptask.online", href: "https://mcptask.online"
      assert_selector "code", text: "main"
      assert_text "A merge is not a release"
    end

    visit root_url(locale: :cs)

    within "#built" do
      assert_selector "h2", text: "Píší ho AI vývojáři. Zadání píší lidé."
      assert_link "mcptask.online", href: "https://mcptask.online"
      assert_selector "code", text: "main"
      assert_text "Merge není vydání"
    end
  end

  test "both calls to action point at the live board and the contributing guide" do
    visit root_url

    within "#built" do
      assert_link "Watch it live", href: "https://mcptask.online/live"
      assert_link "Contribute", href: "https://github.com/jchsoft/mcp4mail/blob/main/CONTRIBUTING.md"
    end

    visit root_url(locale: :cs)

    within "#built" do
      assert_link "Sledovat živě", href: "https://mcptask.online/live"
      assert_link "Přispět", href: "https://github.com/jchsoft/mcp4mail/blob/main/CONTRIBUTING.md"
    end
  end

  # The screenshot arrives after first paint, so the slot has to be the right
  # shape before it does — otherwise the copy above it jumps as it loads.
  test "the screenshot sits in a bordered 3:2 slot that holds its space" do
    visit root_url

    slot = page.evaluate_script(<<~JS)
      (() => {
        const image = document.querySelector("#built img");
        const frame = image.parentElement;
        const box = frame.getBoundingClientRect();
        const style = getComputedStyle(frame);
        return {
          ratio: box.width / box.height,
          radius: style.borderTopLeftRadius,
          border: style.borderTopColor,
          loading: image.loading,
          fit: getComputedStyle(image).objectFit
        };
      })()
    JS

    assert_in_delta 1.5, slot["ratio"], 0.01
    assert_equal "24px", slot["radius"]
    assert_equal LINE, slot["border"]
    assert_equal "lazy", slot["loading"]
    assert_equal "cover", slot["fit"]
  end

  test "the live call to action wears the design's green pill" do
    visit root_url

    pill = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector("#built a[href='https://mcptask.online/live']");
        const style = getComputedStyle(link);
        return { background: style.backgroundColor, color: style.color };
      })()
    JS

    assert_equal GREEN, pill["background"]
    assert_equal "rgb(255, 255, 255)", pill["color"]
  end

  test "the copy stacks above the screenshot at 375px and pairs with it at 1440px" do
    resize_window_to 375, 900
    visit root_url

    stacked = page.evaluate_script(<<~JS)
      (() => {
        const section = document.querySelector("#built");
        const [copy, frame] = section.children;
        return {
          columns: getComputedStyle(section).gridTemplateColumns.split(" ").length,
          imageBelow: frame.getBoundingClientRect().top > copy.getBoundingClientRect().top,
          overflow: Math.round(frame.getBoundingClientRect().right) - document.documentElement.clientWidth
        };
      })()
    JS

    assert_equal 1, stacked["columns"], "the section should stack into one column at 375px"
    assert stacked["imageBelow"], "the screenshot should sit below the copy when stacked"
    assert_operator stacked["overflow"], :<=, 0

    resize_window_to 1440, 900
    visit root_url

    assert_equal 2, page.evaluate_script(%(getComputedStyle(document.querySelector("#built")).gridTemplateColumns.split(" ").length)),
      "the section should be two columns at 1440px"
  ensure
    resize_window_to 1400, 1400
  end

  private
    def resize_window_to(width, height)
      page.current_window.resize_to(width, height)
    end
end
