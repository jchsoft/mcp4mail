require "test_helper"

class MarketingHeaderTest < ActionDispatch::IntegrationTest
  ANCHORS = %w[#why #how #security #built #faq].freeze

  test "the landing page renders through the public layout, not the signed-in chrome" do
    get root_url

    assert_response :success
    assert_select "header.landing-shell", count: 1
    assert_select "main.landing-shell", count: 1
    assert_select "footer.landing-shell", count: 1
    assert_select "header nav a[href='#{new_session_path}']", count: 0
  end

  test "the signed-in pages keep the application layout: its nav and no marketing footer" do
    sign_in_as users(:one)

    get mail_accounts_url
    assert_select "footer.landing-shell", count: 0
    assert_select "nav a[href='#{connect_ai_path}']"

    get connect_ai_url
    assert_select "footer.landing-shell", count: 0
    assert_select "nav a[href='#{mail_accounts_path}']"
  end

  test "a visitor sees no account link on the public header" do
    get root_url

    assert_select "#account-link", count: 0
  end

  test "a signed-in person sees who they are on the public screens, linking to the account page" do
    user = users(:one)
    sign_in_as user

    [ root_url, guides_url ].each do |url|
      get url
      assert_select "header #account-link[href=?]", account_path, text: user.email_address
      assert_select "header #account-link[aria-label=?]", "Account (#{user.email_address})"
      assert_select "header #account-link svg", count: 1
    end
  end

  test "the signed-in chrome shows the same account link, marked current on the account page" do
    sign_in_as users(:one)

    get mail_accounts_url
    assert_select "header #account-link[href=?]:not([aria-current])", account_path

    get account_url
    assert_select "header #account-link[aria-current=page]"
  end

  test "the header links to every landing section, with the same ids in both locales" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      ANCHORS.each { |anchor| assert_select "header nav a[href='#{anchor}']", count: 1 }
    end
  end

  test "the header links to the provider guides, in both locales" do
    get root_url(locale: :en)
    assert_select "header nav a[href=?]", guides_path, text: "Guides"

    get root_url(locale: :cs)
    assert_select "header nav a[href=?]", guides_path, text: "Návody"

    get guides_url
    assert_select "header nav a[href=?]", guides_path
  end

  test "the section labels are translated even though the ids are not" do
    get root_url(locale: :en)
    assert_select "header nav a[href='#security']", text: "Security"

    get root_url(locale: :cs)
    assert_select "header nav a[href='#security']", text: "Bezpečnost"
  end

  test "the locale switcher is plain links and the choice sticks across a reload" do
    get root_url
    assert_select "header a[href=?][aria-current='page']", root_path(locale: "en")
    assert_select "header a[href=?]", root_path(locale: "cs")

    get root_path(locale: "cs")
    assert_select "html[lang=cs]"

    get root_path
    assert_select "html[lang=cs]"
    assert_select "header a[href=?][aria-current='page']", root_path(locale: "cs")
  end

  test "the CTA points into the app and differs once signed in" do
    get root_url
    assert_select "header a[href=?]", new_registration_path, text: "Connect a mailbox"

    sign_in_as users(:one)

    get root_url
    assert_select "header a[href=?]", mail_accounts_path, text: "Connect a mailbox"
    assert_select "header a[href=?]", new_registration_path, count: 0
  end

  test "a flash still renders on the public layout" do
    post session_url, params: { email_address: "one@example.com", password: "wrong" }

    # The visitor goes to the landing page instead of following the redirect:
    # the alert is still pending and must not vanish there.
    get root_url

    assert_select "#alert", text: I18n.t("sessions.create.failure")
  end
end
