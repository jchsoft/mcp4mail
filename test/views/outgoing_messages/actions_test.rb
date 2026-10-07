require "test_helper"

class OutgoingMessagesActionsTest < ActionView::TestCase
  test "Send and Discard each post to their own url" do
    render "outgoing_messages/actions", send_url: "/outgoing/tok/approve", discard_url: "/outgoing/tok/discard"

    assert_select "form[action='/outgoing/tok/approve'][method=post] button", text: "Send"
    assert_select "form[action='/outgoing/tok/discard'][method=post] button", text: "Discard"
  end

  test "Send announces itself while submitting" do
    render "outgoing_messages/actions", send_url: "/a", discard_url: "/d"

    assert_select "form[action='/a'][data-turbo-submits-with='Sending…']"
  end

  test "labels follow the locale" do
    I18n.with_locale(:cs) { render "outgoing_messages/actions", send_url: "/a", discard_url: "/d" }

    assert_select "form[action='/a'] button", text: I18n.t("outgoing_messages.actions.send", locale: :cs)
    assert_select "form[action='/d'] button", text: I18n.t("outgoing_messages.actions.discard", locale: :cs)
  end
end
