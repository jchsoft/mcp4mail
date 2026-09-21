require "test_helper"

class ButtonHelperTest < ActionView::TestCase
  test "the primary pill is ink on orange, never white" do
    classes = button_classes(:primary).split

    assert_includes classes, "bg-brand"
    assert_includes classes, "hover:bg-brand-hover"
    assert_includes classes, "text-ink"
    refute_includes classes, "text-white"
  end

  test "every variant and size is a 44px target below lg with no local focus styles" do
    ButtonHelper::RECIPES.each do |variant, sizes|
      sizes.each_key do |size|
        classes = button_classes(variant, size:)

        assert_includes classes.split, "max-lg:min-h-11", "#{variant}/#{size}"
        refute_match(/\b(focus|focus-visible):|outline-none/, classes, "#{variant}/#{size}")
      end
    end
  end

  test "the destructive button sits on the danger tokens" do
    classes = button_classes(:destructive).split

    assert_includes classes, "bg-danger"
    assert_includes classes, "hover:bg-danger-deep"
  end

  test "on the tint panel the outline pill hovers to surface" do
    classes = button_classes(:secondary, on_tint: true).split

    assert_includes classes, "hover:bg-surface"
    refute_includes classes, "hover:bg-surface-hover"
  end

  test "an unknown variant is an error, not a silent unstyled button" do
    assert_raises(KeyError) { button_classes(:fancy) }
  end

  test "button_link renders an anchor with the recipe and any extra class" do
    html = Nokogiri::HTML.fragment(button_link("Connect mailbox", "/mail_accounts/new", variant: :secondary, class: "mt-4"))
    link = html.at_css("a")

    assert_equal "/mail_accounts/new", link["href"]
    assert_equal "Connect mailbox", link.text
    assert_equal button_classes(:secondary).split + [ "mt-4" ], link["class"].split
  end

  test "button_link takes a block for rich content" do
    html = Nokogiri::HTML.fragment(button_link("/live", variant: :dark) { tag.span("Live") })

    assert_equal "/live", html.at_css("a")["href"]
    assert_equal "Live", html.at_css("a > span").text
  end

  test "the <a> and the <button> share one definition" do
    html = Nokogiri::HTML.fragment(button_to("Remove mailbox", "/mail_accounts/1", method: :delete, class: button_classes(:destructive)))

    assert_equal button_classes(:destructive), html.at_css("button")["class"]
  end

  test "button_submit carries the submitting state" do
    html = Nokogiri::HTML.fragment(
      form_with(url: "/mail_accounts") { |form| button_submit(form, "Connect mailbox") }
    )
    button = html.at_css("button[type=submit]")

    assert_equal "Connect mailbox", button.text
    assert_equal I18n.t("buttons.submitting"), button["data-turbo-submits-with"]
    assert_equal button_classes(:primary), button["class"]
  end

  test "button_submit lets a form name its own submitting label" do
    html = Nokogiri::HTML.fragment(
      form_with(url: "/mail_accounts") { |form| button_submit(form, "Connect mailbox", submitting: "Finding…") }
    )

    assert_equal "Finding…", html.at_css("button")["data-turbo-submits-with"]
  end
end
