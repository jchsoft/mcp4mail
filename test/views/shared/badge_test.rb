require "test_helper"

class SharedBadgeTest < ActionView::TestCase
  test "renders the label in a pill with the given id and extra classes" do
    render "shared/badge", id: "work-calls", class: "ml-2", label: "7"

    assert_select "span#work-calls.ml-2.rounded-full", "7"
  end

  test "defaults to the neutral variant" do
    render "shared/badge", label: "rate limited"

    assert_select "span.bg-surface-hover.border-line.text-ink-soft", "rate limited"
  end

  test "ok wears the green family and denied the danger one" do
    render "shared/badge", variant: :ok, label: "ok"
    assert_select "span.bg-green-tint.border-green.text-green-deep", "ok"

    render "shared/badge", variant: :denied, label: "denied"
    assert_select "span.bg-danger-tint.border-danger.text-danger-deep", "denied"
  end

  test "the colour is decoration, so the badge adds nothing for a screen reader to announce" do
    render "shared/badge", variant: :denied, label: "denied"

    assert_select "span[role]", false
    assert_select "span[aria-label]", false
  end
end
