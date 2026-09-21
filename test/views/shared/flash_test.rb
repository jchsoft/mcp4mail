require "test_helper"

class SharedFlashTest < ActionView::TestCase
  test "the alert is on the danger tokens and interrupts assistive technology" do
    flash[:alert] = "Try again."
    render "shared/flash"

    assert_select "p#alert[role=alert][aria-live=assertive].bg-danger-tint.border-danger.text-danger-deep", "Try again."
    assert_select "#notice", false
  end

  test "the notice is a polite status region" do
    flash[:notice] = "Saved."
    render "shared/flash"

    assert_select "p#notice[role=status][aria-live=polite].bg-green-tint", "Saved."
    assert_select "#alert", false
  end

  test "renders nothing without a flash" do
    render "shared/flash"

    assert_empty rendered.strip
  end
end
