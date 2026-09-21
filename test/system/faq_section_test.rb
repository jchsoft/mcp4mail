require "application_system_test_case"

class FaqSectionTest < ApplicationSystemTestCase
  test "the six questions render from the locale, in either language" do
    visit root_url

    within "#faq" do
      # The kicker is the section's h2 since task #12708: the FAQ was the one
      # section the heading outline did not mention.
      assert_selector "h2", text: /questions/i
      assert_selector "details", count: 6
      assert_selector "summary", text: "Do I have to install anything?"
      assert_selector "summary", text: "What does it cost?"
      assert_selector "summary", text: "Do I need this for Gmail or Outlook?"
    end

    visit root_url(locale: :cs)

    within "#faq" do
      assert_selector "details", count: 6
      assert_selector "summary", text: "Musím něco instalovat?"
      assert_selector "summary", text: "Kolik to stojí?"
    end
  end

  test "a question opens on click and closes again, and the answer follows it" do
    visit root_url

    answer = "The hosted version runs at mcp4mail.online"
    assert_no_text answer

    find("#faq summary", text: "Do I have to install anything?").click
    assert_text answer

    find("#faq summary", text: "Do I have to install anything?").click
    assert_no_text answer
  end

  test "the keyboard opens a question with Enter and with Space" do
    visit root_url

    summary = find("#faq summary", text: "What does it cost?")

    summary.send_keys(:enter)
    assert_text "The code is open source under the MIT license"

    summary.send_keys(:enter)
    assert_no_text "The code is open source under the MIT license"

    summary.send_keys(:space)
    assert_text "The code is open source under the MIT license"
  end

  test "a summary reached from the keyboard takes the page's visible focus ring" do
    visit root_url

    # Focus has to arrive by keyboard: :focus-visible is about how the element
    # was reached, so a script-driven focus() would not prove the visitor sees
    # a ring.
    # Tab out of the fourth question and the fifth is where focus lands, the
    # questions being in the tab order in document order.
    find("#faq summary", text: "What does mcp4mail store?").send_keys(:tab)

    outline = page.evaluate_script(<<~JS)
      (() => {
        const summary = document.activeElement;
        const styles = getComputedStyle(summary);
        return {
          tag: summary.tagName,
          text: summary.textContent.trim(),
          matches: summary.matches(":focus-visible"),
          width: styles.outlineWidth,
          style: styles.outlineStyle,
          color: styles.outlineColor,
          shadow: styles.boxShadow
        };
      })()
    JS

    assert_equal "SUMMARY", outline["tag"]
    assert_includes outline["text"], "What does it cost?"
    assert outline["matches"], "expected the summary to match :focus-visible after keyboard focus"
    assert_equal "3px", outline["width"]
    assert_equal "solid", outline["style"]
    # The ring went two-tone on task #12708 — the outline is ink, and the brand
    # orange it used to be now fills the offset gap as a box-shadow. A single
    # orange ring was only 2.87:1 against this cream page.
    assert_equal "rgb(31, 36, 48)", outline["color"]
    assert_includes outline["shadow"], "rgb(242, 107, 29)"
  end

  test "several answers can stay open at once" do
    visit root_url

    find("#faq summary", text: "Do I have to install anything?").click
    find("#faq summary", text: "What does it cost?").click

    assert_selector "#faq details[open]", count: 2
  end

  test "the marker rotates when its question opens, and is not animated under reduced motion" do
    visit root_url

    assert_equal "none", marker_transform

    find("#faq summary", text: "Do I have to install anything?").click
    # rotate(45deg) as a computed matrix once the .2s transition has run out:
    # cos/sin of 45° on both axes.
    assert_match(/matrix\(0\.7071/, settled_marker_transform)

    assert_equal "0.2s", marker_transition_duration

    # The opt-out is a media query, which the driver cannot toggle mid-session,
    # so assert the rule itself is in the stylesheet the page loaded.
    assert page.evaluate_script(<<~JS), "expected a prefers-reduced-motion rule turning the marker transition off"
      (() => {
        // The rule sits inside the base cascade layer, so walk nested rules
        // rather than only the stylesheet's top level.
        const search = (rules, reduced) =>
          Array.from(rules).some((rule) => {
            const here = reduced ||
              (rule.media && rule.media.mediaText.includes("prefers-reduced-motion"));
            if (here && rule.selectorText === ".faq-mark") {
              return rule.style.transition === "none";
            }
            return rule.cssRules ? search(rule.cssRules, here) : false;
          });
        return Array.from(document.styleSheets).some((sheet) => search(sheet.cssRules, false));
      })()
    JS
  end

  test "the header link jumps to the FAQ" do
    visit root_url

    assert_link "FAQ", href: "#faq"
    click_link "FAQ"
    assert_equal "#faq", settled_location_hash
  end

  private
    # click_link returns once the click is dispatched, not once the browser has
    # acted on it, and none of Capybara's waiting matchers look at the fragment.
    # Reading location.hash straight after the click therefore raced the
    # navigation and caught an empty string on a loaded CI runner. Poll instead.
    def settled_location_hash
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      hash = page.evaluate_script("location.hash")
      while hash.to_s.empty? && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.05
        hash = page.evaluate_script("location.hash")
      end
      hash
    end

    # The rotation is animated, so the first read catches it part-way round.
    def settled_marker_transform
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      transform = marker_transform
      until transform.start_with?("matrix(0.7071") || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.05
        transform = marker_transform
      end
      transform
    end

    def marker_transform
      page.evaluate_script(%(getComputedStyle(document.querySelector("#faq .faq-mark")).transform))
    end

    def marker_transition_duration
      page.evaluate_script(%(getComputedStyle(document.querySelector("#faq .faq-mark")).transitionDuration))
    end
end
