require "test_helper"

class TailwindThemeTest < ActiveSupport::TestCase
  SOURCE = Rails.root.join("app/assets/tailwind/application.css")

  # The palette of docs/design/landing-v2.html, with the four values the
  # accessibility pass of task #12708 moved. Those four are marked below with
  # the design's original and the ratio that failed; every other token is the
  # design's own and a diff here means the page has drifted from the mock.
  # docs/accessibility/axe-report.md carries the full measurement table.
  REQUIRED_COLORS = {
    "paper" => "#fbf8f3",
    "ink" => "#1f2430",
    "ink-soft" => "#4a515f",
    "ink-muted" => "#5c626e",    # design #6b7280: 4.56:1 on paper, and every use renders at 13-14px
    "ink-on-dark" => "#cfd3dc",
    "code-chip" => "#343b4a",
    "brand" => "#f26b1d",
    "brand-hover" => "#f5792f",  # design #e35f14: the ink CTA label read 4.37:1 on it
    "brand-deep" => "#bc430f",   # design #c94a12: kickers and the nav hover read 4.43:1 on paper
    "brand-tint" => "#fde9dc",
    "green" => "#1a7a63",        # design #1f8a70: white on the live pill 4.26:1, the token as link text 4.02:1
    "green-deep" => "#15654f",
    "green-tint" => "#dff3ec",
    "highlight" => "#ffd166",
    "surface" => "#ffffff",
    "surface-hover" => "#f1ebe1",
    "line" => "#ebe4d8",
    # Added by task #12800, which had no design value to start from: chosen
    # against paper and surface, and measured in docs/accessibility/axe-report.md.
    "danger" => "#b8321c",
    "danger-deep" => "#8f2613",
    "danger-tint" => "#fbe3dc",
    "field-border" => "#8a8378",
    "field-placeholder" => "#6f6a63"
  }.freeze

  REQUIRED_HEADING_SIZES = {
    "h1" => "clamp(42px, 5.6vw, 72px)",
    "h2" => "clamp(30px, 3.6vw, 46px)",
    "h2-sub" => "clamp(28px, 3.4vw, 42px)"
  }.freeze

  setup { @css = SOURCE.read }

  test "every design colour is declared as a theme token" do
    REQUIRED_COLORS.each do |name, value|
      assert_includes @css, "--color-#{name}: #{value};",
                      "expected --color-#{name} to be defined as #{value}"
    end
  end

  test "fluid heading sizes are theme tokens rather than inline clamps" do
    REQUIRED_HEADING_SIZES.each do |name, value|
      assert_includes @css, "--text-#{name}: #{value};",
                      "expected --text-#{name} to be defined as #{value}"
    end
  end

  test "heading and body families are registered as theme tokens" do
    assert_match(/--font-heading:\s*"Bricolage Grotesque"/, @css)
    assert_match(/--font-body:\s*"Instrument Sans"/, @css)
    assert_match(/--font-code:\s*ui-monospace, monospace;/, @css)
  end

  test "theme block is static so unused tokens still reach the stylesheet" do
    assert_includes @css, "@theme static {",
                    "section subtasks rely on every token being emitted, not only the ones already used"
  end

  test "fonts are self-hosted, never fetched from Google" do
    assert_no_match(/fonts\.googleapis\.com|fonts\.gstatic\.com/, @css)

    families = @css.scan(/@font-face\s*\{(.+?)\}/m).flatten
    assert_equal 6, families.size, "expected latin and latin-ext faces for both families plus the italic"

    families.each do |face|
      file = face[/url\("([^"]+)"\)/, 1]
      assert file, "every @font-face needs a src url"
      assert_includes face, "font-display: swap;", "#{file} must not block first paint"
      assert Rails.root.join("app/assets/fonts", file).exist?,
             "#{file} is referenced but not vendored under app/assets/fonts"
    end
  end

  test "font files are fingerprinted by propshaft" do
    Dir.children(Rails.root.join("app/assets/fonts")).each do |file|
      asset = Rails.application.assets.load_path.find(file)
      assert asset, "#{file} is not on the asset load path"
      assert_match(/-[0-9a-f]{8}\.woff2\z/, asset.digested_path.to_s)
    end
  end

  test "base layer applies the design's page defaults" do
    base = @css[/@layer base \{.+\z/m]
    assert base, "expected a @layer base block"

    assert_includes base, "background-color: var(--color-paper);"
    assert_includes base, "color: var(--color-ink);"
    assert_includes base, "font-family: var(--font-body);"
    assert_includes base, "scroll-behavior: smooth;"
    assert_includes base, "::selection"
    assert_includes base, "*:focus-visible"
    assert_includes base, "details summary::-webkit-details-marker"
  end
end
