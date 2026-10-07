require "test_helper"

class OutgoingMessagesPreviewTest < ActionView::TestCase
  setup do
    @account = mail_accounts(:work)
  end

  test "lists sender, recipients, subject and the body" do
    render "outgoing_messages/preview", outgoing_message: prepare(cc: [ "carol@example.org" ], bcc: [ "dave@example.org" ])

    assert_select "dt", text: "From"
    assert_select "dd", text: @account.sender_address
    assert_select "dt", text: "To"
    assert_select "dd", text: "bob@example.org"
    assert_select "dt", text: "Cc"
    assert_select "dd", text: "carol@example.org"
    assert_select "dt", text: "Bcc"
    assert_select "dd", text: "dave@example.org"
    assert_select "dt", text: "Subject"
    assert_select "dd", text: "Lunch"
    assert_select "pre", text: "Friday at noon?"
  end

  test "leaves out Cc and Bcc when there are none" do
    render "outgoing_messages/preview", outgoing_message: prepare

    assert_select "dt", text: "Cc", count: 0
    assert_select "dt", text: "Bcc", count: 0
  end

  test "labels follow the locale" do
    message = prepare(cc: [ "carol@example.org" ])
    I18n.with_locale(:cs) { render "outgoing_messages/preview", outgoing_message: message }

    assert_select "dt", text: I18n.t("outgoing_messages.preview.from", locale: :cs)
    assert_select "dt", text: I18n.t("outgoing_messages.preview.subject", locale: :cs)
    assert_select "dt", text: "From", count: 0
  end

  test "escapes the body instead of rendering markup" do
    render "outgoing_messages/preview", outgoing_message: prepare(body: "<b>bold</b>")

    assert_select "pre b", false
    assert_select "pre", text: "<b>bold</b>"
  end

  private

  def prepare(cc: [], bcc: [], body: "Friday at noon?")
    composer = MessageComposer.new(@account, to: [ "bob@example.org" ], cc:, bcc:, subject: "Lunch", body:)
    OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
  end
end
