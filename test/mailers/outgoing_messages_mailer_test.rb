require "test_helper"

class OutgoingMessagesMailerTest < ActionMailer::TestCase
  setup do
    composer = MessageComposer.new(mail_accounts(:work), to: [ "bob@example.org" ], cc: [ "carol@example.org" ],
      subject: "Lunch", body: "Friday at noon?")
    @outgoing = OutgoingMessage.prepare!(mail_account: mail_accounts(:work), client_id: "claude", composer:)
  end

  test "approval carries the whole message and the one link" do
    mail = OutgoingMessagesMailer.approval(@outgoing, @outgoing.raw_token)

    assert_equal [ users(:one).email_address ], mail.to
    assert_equal "Approve: Lunch to bob@example.org", mail.subject

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, "bob@example.org"
      assert_includes body, "carol@example.org"
      assert_includes body, "Friday at noon?"
      assert_includes body, "http://example.com/outgoing/#{@outgoing.raw_token}/approve"
    end
  end

  test "approval is translated into Czech" do
    subject = I18n.with_locale(:cs) { OutgoingMessagesMailer.approval(@outgoing, @outgoing.raw_token).subject }

    assert_equal "Schválit: Lunch pro bob@example.org", subject
  end
end
