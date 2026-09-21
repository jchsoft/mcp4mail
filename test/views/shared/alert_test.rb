require "test_helper"

class SharedAlertTest < ActionView::TestCase
  test "renders the body inside a box with the given id and extra classes" do
    render "shared/alert", id: "no-mailbox", class: "mt-6", body: "Add a mailbox first."

    assert_select "div#no-mailbox.mt-6.rounded-xl", "Add a mailbox first."
  end

  test "a title leads and the body follows as its hint" do
    render "shared/alert", title: "Could not connect", body: "Check the password."

    assert_select "div > p.font-medium", "Could not connect"
    assert_select "div > p.text-sm", "Check the password."
  end

  test "defaults to info, on the neutral surface, without a live role" do
    render "shared/alert", body: "Guidance"

    assert_select "div.bg-surface.border-line.text-ink-soft"
    assert_select "div[role]", false
  end

  test "warning uses the brand tint" do
    render "shared/alert", variant: :warning, body: "Check this"

    assert_select "div.bg-brand-tint.border-brand.text-brand-deep"
    assert_select "div[role]", false
  end

  test "danger uses the danger tokens and is announced" do
    render "shared/alert", variant: :danger, body: "Failed"

    assert_select "div[role=alert].bg-danger-tint.border-danger.text-danger-deep", "Failed"
  end

  test "an unknown variant is an error, not a silent default" do
    assert_raises(ActionView::Template::Error) { render "shared/alert", variant: :success, body: "x" }
  end
end
