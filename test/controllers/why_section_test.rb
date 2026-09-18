require "test_helper"

class WhySectionTest < ActionDispatch::IntegrationTest
  test "the section carries the id the header's anchor points at, in both locales" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      assert_response :success
      assert_select "section#why", count: 1
      assert_select "header nav a[href='#why']", count: 1
    end
  end

  test "the three cards come from the locale array, not from the markup" do
    I18n.available_locales.each do |locale|
      get root_url(locale: locale)

      cards = I18n.t("pages.home.why.cards", locale: locale)
      assert_select "section#why figure", count: cards.size

      cards.each_with_index do |card, index|
        assert_select "section#why figure:nth-of-type(#{index + 1}) blockquote", text: card[:quote]
        assert_select "section#why figure:nth-of-type(#{index + 1}) figcaption", text: card[:note]
      end
    end
  end

  test "each locale keeps its own quotation marks" do
    get root_url(locale: :cs)
    assert_select "section#why blockquote", text: /\A„.+“\z/

    get root_url(locale: :en)
    assert_select "section#why blockquote", text: /\A“.+”\z/
  end

  test "the intro renders the kicker, heading and lede of the current locale" do
    get root_url(locale: :cs)

    assert_select "section#why span", text: I18n.t("pages.home.why.kicker", locale: :cs)
    assert_select "section#why h2", text: I18n.t("pages.home.why.heading", locale: :cs)
    assert_select "section#why p", text: I18n.t("pages.home.why.lede", locale: :cs)
  end

  test "the cards add no heading level below the section's h2" do
    get root_url

    assert_select "section#why h2", count: 1
    assert_select "section#why figure :is(h1, h2, h3, h4, h5, h6)", count: 0
  end
end
