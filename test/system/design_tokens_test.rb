require "application_system_test_case"

class DesignTokensTest < ApplicationSystemTestCase
  PAPER = "rgb(251, 248, 243)".freeze

  # landing-shell's max-width, in application.css. The scaffold column this
  # replaced (`container mx-auto`) sized to the viewport's breakpoint instead,
  # so the number is a signature: it is not what any Tailwind class alone gives.
  SHELL_MAX_WIDTH = "1160px".freeze

  test "the landing page picks up the design's paper background and body typeface" do
    visit root_url

    assert_equal PAPER, computed_body_style("background-color")
    assert_includes computed_body_style("font-family"), "Instrument Sans"
  end

  test "the signed-in pages still render on the same tokens" do
    user = users(:one)

    visit new_session_url
    fill_in placeholder: "Enter your email address", with: user.email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    visit mail_accounts_url
    assert_selector "h1"
    assert_equal PAPER, computed_body_style("background-color")
    assert_signed_in_shell

    visit connect_ai_url
    assert_selector "h1", text: "Connect AI"
    assert_equal PAPER, computed_body_style("background-color")
    assert_signed_in_shell
  end

  test "no stylesheet or font is fetched from Google" do
    visit root_url

    hosts = page.evaluate_script(<<~JS)
      Array.from(document.styleSheets).map(sheet => sheet.href).filter(Boolean)
    JS
    assert hosts.any?, "expected the page to link at least one stylesheet"
    hosts.each { |href| assert_match %r{\A#{Regexp.escape(page.server_url)}/}, href }

    font_sources = page.evaluate_script(<<~JS)
      Array.from(document.styleSheets)
        .flatMap(sheet => Array.from(sheet.cssRules))
        .filter(rule => rule instanceof CSSFontFaceRule)
        .map(rule => rule.style.getPropertyValue('src'))
    JS
    assert_equal 6, font_sources.size, "expected the six self-hosted faces"
    font_sources.each do |src|
      assert_no_match(/gstatic|googleapis/, src)
      assert_match %r{/assets/[\w-]+-[0-9a-f]{8}\.woff2}, src
    end
  end

  private
    def computed_body_style(property)
      computed_style("body", property)
    end

    def computed_style(selector, property)
      page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).getPropertyValue(#{property.to_json})")
    end

    # The signed-in shell of layouts/application.html.erb: the skip link, the
    # app header and main#main inside the landing column. Asserted here rather
    # than in a controller test because the column is a measurement — the
    # layout could revert to the scaffold's `container mx-auto` and every other
    # assertion in this file would stay green. main#main carries the shell
    # itself, and the header has to sit on the same edges, so the page body and
    # the nav cannot drift apart.
    def assert_signed_in_shell
      assert_selector "header"
      assert_selector "main#main"

      assert_equal SHELL_MAX_WIDTH, computed_style("main#main", "max-width"),
                   "main#main must render in the landing shell's column"
      assert_equal computed_style("header", "max-width"), SHELL_MAX_WIDTH,
                   "the app header must share the shell's column"
      assert_equal computed_style("header", "padding-left"), computed_style("main#main", "padding-left"),
                   "the app header and the page body must share the shell's gutter"

      # Present, and off-screen until it takes focus: the `skip-link` utility
      # is what keeps it out of the way, so this pins the utility and not only
      # the link.
      assert_selector "a.skip-link", visible: :all
      assert_operator page.evaluate_script("document.querySelector('.skip-link').getBoundingClientRect().right"), :<, 0,
                      "the skip link must sit off-screen until it takes focus"
    end
end
