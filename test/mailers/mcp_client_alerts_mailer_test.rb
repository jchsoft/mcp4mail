require "test_helper"

class McpClientAlertsMailerTest < ActionMailer::TestCase
  setup do
    @sighting = McpClientSighting.create!(user: users(:one), mail_account: mail_accounts(:work),
      client_id: "claude", remote_ip: "127.0.0.1", first_seen_at: Time.utc(2026, 9, 21, 8, 30))
  end

  test "new_client names the mailbox, client, address and time and links to the mailboxes" do
    mail = McpClientAlertsMailer.new_client(@sighting)

    assert_equal [ users(:one).email_address ], mail.to
    assert_equal "A new AI client is reading Work", mail.subject

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, "claude"
      assert_includes body, "127.0.0.1"
      assert_includes body, "2026-09-21 08:30 UTC"
      assert_includes body, "http://example.com/mail_accounts"
    end
  end

  test "new_client is translated into Czech" do
    mail = I18n.with_locale(:cs) { McpClientAlertsMailer.new_client(@sighting) }

    assert_equal "Nový AI klient čte schránku Work", mail.subject
  end
end
