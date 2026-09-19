require "test_helper"

class HowSectionTest < ActionDispatch::IntegrationTest
  test "the section carries the id the header's anchor points at, in both locales" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      assert_response :success
      assert_select "section#how", count: 1
      assert_select "header nav a[href='#how']", count: 1
    end
  end

  test "the steps are an ordered list, one item per locale entry" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      steps = I18n.t("pages.home.how.steps", locale: locale)
      assert_select "section#how ol", count: 1
      assert_select "section#how ol > li", count: steps.size
      assert_select "section#how ul", count: 0

      steps.each_with_index do |step, index|
        assert_select "section#how ol > li:nth-child(#{index + 1}) h3", text: step[:title]
      end
    end
  end

  test "each numeral is hidden from assistive technology, which reads the list instead" do
    get root_url

    assert_select "section#how ol > li > span[aria-hidden=true]", count: 3
    assert_select "section#how ol[role=list]", count: 1
  end

  test "the inline emphasis of the copy survives into the page" do
    get root_url(locale: :en)

    assert_select "section#how ol > li:nth-child(1) p strong", text: "app password"
    assert_select "section#how ol > li:nth-child(2) p code", count: 1

    get root_url(locale: :cs)

    assert_select "section#how ol > li:nth-child(1) p strong", text: "heslo aplikace"
  end

  test "the connector address comes from the connector's own configuration" do
    get root_url

    assert_select "section#how code", text: Hitch.configuration.resource_uri.sub(%r{\Ahttps?://}, "")
  end

  test "no locale file carries the connector address as a literal" do
    I18n.available_locales.each do |locale|
      steps = I18n.t("pages.home.how.steps", locale: locale)

      assert_includes steps.map { |step| step[:body_html] }.join, "%{connector_url}",
                      "the #{locale} copy should interpolate the address, not hard-code it"
    end
  end

  test "the client chips render from the locale array and are not links" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      clients = I18n.t("pages.home.how.clients", locale: locale)
      clients.each { |client| assert_select "section#how span", text: client }
      assert_select "section#how a", count: 0
    end
  end

  test "the intro renders the kicker and heading of the current locale" do
    get root_url(locale: :cs)

    assert_select "section#how span", text: I18n.t("pages.home.how.kicker", locale: :cs)
    assert_select "section#how h2", text: I18n.t("pages.home.how.heading", locale: :cs)
  end
end
