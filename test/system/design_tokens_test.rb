require "application_system_test_case"

class DesignTokensTest < ApplicationSystemTestCase
  PAPER = "rgb(251, 248, 243)".freeze

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

    visit connect_ai_url
    assert_selector "h1", text: "Connect AI"
    assert_equal PAPER, computed_body_style("background-color")
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
      page.evaluate_script("getComputedStyle(document.body).getPropertyValue('#{property}')")
    end
end
