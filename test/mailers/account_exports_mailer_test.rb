require "test_helper"

class AccountExportsMailerTest < ActionMailer::TestCase
  setup do
    @export = AccountExportFile.start!(users(:one))
  end

  test "ready goes to the owner and carries the one-time download link" do
    mail = AccountExportsMailer.ready(@export, @export.raw_token)

    assert_equal [ users(:one).email_address ], mail.to
    assert_equal "Your mcp4mail data export is ready", mail.subject

    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.to_s
      assert_includes body, "http://example.com/account/export/#{@export.raw_token}"
      assert_includes body, "1 day"
    end
  end
end
