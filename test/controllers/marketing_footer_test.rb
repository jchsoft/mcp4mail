require "test_helper"

class MarketingFooterTest < ActionDispatch::IntegrationTest
  SELF_HOSTING_URL = "https://github.com/jchsoft/mcp4mail/blob/main/docs/self-hosting.md".freeze

  test "the closing CTA carries the design's two buttons and points into the app" do
    get root_url

    assert_select "main section:last-of-type" do
      assert_select "h2", text: "Your mailbox is waiting for its first question."
      assert_select "a[href=?]", new_registration_path, text: "Connect a mailbox"
      assert_select "a[href=?]", "https://github.com/jchsoft/mcp4mail", text: "GitHub"
    end
  end

  test "the closing CTA sends a signed-in visitor to their mailboxes" do
    sign_in_as users(:one)

    get root_url

    assert_select "main section:last-of-type a[href=?]", mail_accounts_path, text: "Connect a mailbox"
    assert_select "main section:last-of-type a[href=?]", new_registration_path, count: 0
  end

  test "the closing CTA is translated" do
    get root_url(locale: :cs)

    assert_select "main section:last-of-type" do
      assert_select "h2", text: "Vaše schránka už čeká na první otázku."
      assert_select "a[href=?]", new_registration_path, text: "Připojit schránku"
    end
  end

  test "the footer keeps the design's split of two links and two statements" do
    get root_url

    assert_select "footer" do
      assert_select "a[href=?]", "https://github.com/jchsoft/mcp4mail", text: "GitHub"
      assert_select "a[href=?]", "https://mcptask.online/live", text: "Built live on mcptask.online"
      assert_select "span", text: "mcp4mail · MIT"
      assert_select "span", text: "JCHSoft"
      assert_select "a", text: "mcp4mail · MIT", count: 0
      assert_select "a", text: "JCHSoft", count: 0
    end
  end

  test "the footer adds the self-hosting guide the design does not draw" do
    get root_url
    assert_select "footer a[href=?]", SELF_HOSTING_URL, text: "Self‑hosting guide"

    get root_url(locale: :cs)
    assert_select "footer a[href=?]", SELF_HOSTING_URL, text: "Návod k self‑hostingu"
  end

  test "the footer links to the provider guides" do
    get root_url
    assert_select "footer a[href=?]", guides_path, text: "Setup guides"

    get root_url(locale: :cs)
    assert_select "footer a[href=?]", guides_path, text: "Návody k nastavení"
  end

  test "the footer carries its own locale switcher, reflecting the current locale" do
    get root_url
    assert_select "footer a[href=?][aria-current='page']", root_path(locale: "en")
    assert_select "footer a[href=?]", root_path(locale: "cs")

    get root_path(locale: "cs")
    assert_select "footer a[href=?][aria-current='page']", root_path(locale: "cs")
  end
end
