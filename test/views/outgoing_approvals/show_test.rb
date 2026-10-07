require "test_helper"

class OutgoingApprovalsShowTest < ActionView::TestCase
  setup do
    @account = mail_accounts(:work)
    composer = MessageComposer.new(@account, to: [ "bob@example.org" ], subject: "Lunch", body: "Friday at noon?")
    @message = OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
  end

  test "a pending message shows the preview with Send and Discard" do
    show

    assert_select "h1", text: "Approve an email"
    assert_select "p", text: /#{Regexp.escape(@account.label)}/
    assert_select "dd", text: "bob@example.org"
    assert_select "pre", text: "Friday at noon?"
    assert_select "form[action='/outgoing/tok/approve'] button", text: "Send"
    assert_select "form[action='/outgoing/tok/discard'] button", text: "Discard"
    assert_select "#outgoing-state", false
  end

  test "the page is in Czech" do
    I18n.with_locale(:cs) { show }

    assert_select "h1", text: "Schválit e-mail"
    assert_select "form[action='/outgoing/tok/approve'] button", text: I18n.t("outgoing_messages.actions.send", locale: :cs)
  end

  test "a sent message shows an info state and no buttons" do
    @message.update!(state: "sent")
    show

    assert_select "#outgoing-state", text: "This email has been sent."
    assert_select "form", false
    assert_select "dl", false
  end

  test "discarded and expired messages say so, in both languages" do
    { "discarded" => "This email was discarded. Nothing was sent.",
      "expired" => "This link has expired after 24 hours. Nothing was sent." }.each do |state, text|
      @message.update!(state:)
      show
      assert_select "#outgoing-state", text: text
      assert_select "form", false

      I18n.with_locale(:cs) { show }
      assert_select "#outgoing-state", text: I18n.t("outgoing_approvals.show.states.#{state}", locale: :cs)
    end
  end

  private

  def show
    @outgoing_message = @message
    controller.params[:token] = "tok"
    render template: "outgoing_approvals/show"
  end
end
