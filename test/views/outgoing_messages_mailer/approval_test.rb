require "test_helper"

class OutgoingMessagesMailerApprovalViewTest < ActionMailer::TestCase
  setup do
    @account = mail_accounts(:work)
    composer = MessageComposer.new(@account, to: [ "bob@example.org" ], cc: [ "carol@example.org" ],
      bcc: [ "dave@example.org" ], subject: "Lunch", body: "Friday at noon?")
    @outgoing = OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
    @url = "http://example.com/outgoing/#{@outgoing.raw_token}/approve"
  end

  test "html part: intro, preview, review link, expiry and warning" do
    html = Nokogiri::HTML.fragment(approval.html_part.body.to_s)

    assert_match(/claude wants to send this email from your mailbox #{Regexp.escape(@account.label)}/, html.text)
    assert_equal %w[From To Cc Bcc Subject], html.css("dt").map(&:text)
    assert_includes html.css("dd").map(&:text), "carol@example.org"
    assert_equal "Friday at noon?", html.at_css("pre").text
    assert_equal "Review and send", html.at_css("a[href='#{@url}']").text
    assert_includes html.text, "expires in 24 hours"
    assert_includes html.text, "If you did not ask your AI app for this"
  end

  test "text part: labelled lines, the body and the link" do
    text = approval.text_part.body.to_s

    assert_includes text, "From: #{@account.sender_address}"
    assert_includes text, "To: bob@example.org"
    assert_includes text, "Cc: carol@example.org"
    assert_includes text, "Bcc: dave@example.org"
    assert_includes text, "Subject: Lunch"
    assert_includes text, "Friday at noon?"
    assert_includes text, "Review and send: #{@url}"
    assert_includes text, "expires in 24 hours"
  end

  test "text part leaves out Cc and Bcc lines when empty" do
    composer = MessageComposer.new(@account, to: [ "bob@example.org" ], subject: "Hi", body: "x")
    outgoing = OutgoingMessage.prepare!(mail_account: @account, client_id: "claude", composer:)
    text = OutgoingMessagesMailer.approval(outgoing, outgoing.raw_token).text_part.body.to_s

    assert_not_includes text, "Cc:"
    assert_not_includes text, "Bcc:"
  end

  test "both parts are in Czech" do
    html, text = I18n.with_locale(:cs) { approval.then { |mail| [ mail.html_part.body.to_s, mail.text_part.body.to_s ] } }
    review = I18n.t("outgoing_messages_mailer.approval.review", locale: :cs)
    from = I18n.t("outgoing_messages.preview.from", locale: :cs)

    assert_equal review, Nokogiri::HTML.fragment(html).at_css("a[href='#{@url}']").text
    assert_includes text, "#{review}: #{@url}"
    assert_includes text, "#{from}: #{@account.sender_address}"
    assert_not_includes text, "Review and send"
  end

  private

  def approval
    OutgoingMessagesMailer.approval(@outgoing, @outgoing.raw_token)
  end
end
