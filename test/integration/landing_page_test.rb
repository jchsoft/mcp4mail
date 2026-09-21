require "test_helper"

class LandingPageTest < ActionDispatch::IntegrationTest
  ANCHOR_IDS = %w[why how security built faq].freeze

  test "the landing page lays out its sections in order, with the ids the header links to" do
    get root_url

    assert_response :success
    sections = css_select("main > section")
    assert_equal 7, sections.size, "hero, why, how, security, built, faq and the closing CTA"
    assert_equal [ nil, "why", "how", "security", "built", "faq", nil ], sections.map { |s| s["id"] }

    ANCHOR_IDS.each do |id|
      assert_select "header nav a[href='##{id}']", count: 1
      assert_select "main section##{id}", count: 1
    end
    assert_select "footer", count: 1
  end

  test "both locales render the whole page and set html lang" do
    get root_url(locale: :cs)
    assert_select "html[lang=cs]"
    assert_select "main > section", count: 7
    assert_select "#faq details", count: 6
    assert_select "header nav a[href='#security']", text: "Bezpečnost"

    get root_url(locale: :en)
    assert_select "html[lang=en]"
    assert_select "main > section", count: 7
    assert_select "#faq details", count: 6
    assert_select "header nav a[href='#security']", text: "Security"
  end

  test "the page says who it is for and links every provider guide" do
    get root_url

    assert_select "main > section:first-of-type p", text: /Your mail is not on Gmail\?/
    Guide.all.each do |guide|
      assert_select "main a[href=?]", guide_path(guide), text: guide.title
    end
    assert_select "main a[href=?]", guides_path, text: "All setup guides →"

    get root_url(locale: :cs)
    assert_select "main > section:first-of-type p", text: /Nemáte poštu na Gmailu\?/
    assert_select "main a[href=?]", guides_path, text: "Všechny návody →"
  end

  test "the page names no price, plan or upgrade: the project is free" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      text = css_select("body").text
      [ /\bpric(e|ing)\b/i, /\bplans?\b/i, /\bPro\b/, /\bupgrade\b/i, /\bceník\b/i, /\bpředplatné\b/i ].each do |pattern|
        assert_no_match pattern, text, "#{locale}: the landing page must not mention #{pattern.source}"
      end
    end
  end

  test "signed out, every call to action points at registration" do
    get root_url

    assert_select "header a[href=?]", new_registration_path
    assert_select "main > section:first-of-type a[href=?]", new_registration_path
    assert_select "main > section:last-of-type a[href=?]", new_registration_path
    assert_select "a[href=?]", mail_accounts_path, count: 0
  end

  test "signed in, every call to action points at the mailboxes" do
    sign_in_as users(:one)

    get root_url

    assert_select "header a[href=?]", mail_accounts_path
    assert_select "main > section:first-of-type a[href=?]", mail_accounts_path
    assert_select "main > section:last-of-type a[href=?]", mail_accounts_path
    assert_select "a[href=?]", new_registration_path, count: 0
  end

  test "external links point where they should" do
    get root_url

    assert_select "main > section:first-of-type a[href=?]", "https://github.com/jchsoft/mcp4mail"
    assert_select "#built a[href=?]", "https://mcptask.online"
    assert_select "#built a[href=?]", "https://mcptask.online/live"
    assert_select "#security a[href=?]", "https://github.com/jchsoft/mcp4mail/blob/main/docs/self-hosting.md"
    assert_select "footer a[href=?]", "https://github.com/jchsoft/mcp4mail/blob/main/docs/self-hosting.md"
  end

  test "the landing page uses the public layout and the mailboxes the application layout" do
    get root_url
    assert_response :success
    assert_select "header.landing-shell", count: 1

    sign_in_as users(:one)
    get mail_accounts_url
    assert_response :success
    assert_select "footer.landing-shell", count: 0
    assert_select "nav a[href=?]", connect_ai_path
  end
end
