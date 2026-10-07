require "test_helper"

class AccountExportsMailerReadyViewTest < ActionMailer::TestCase
  setup do
    @export = AccountExportFile.start!(users(:one))
    @url = "http://example.com/account-exports/#{@export.raw_token}"
    @mail = AccountExportsMailer.ready(@export, @export.raw_token)
  end

  test "html part links to the download and states the lifetime" do
    html = Nokogiri::HTML.fragment(@mail.html_part.body.to_s)

    assert_equal "download it here", html.at_css("a[href='#{@url}']").text
    assert_includes html.text, "The link works for 1 day"
    assert_includes html.text, "deleted from our servers"
  end

  test "text part has the bare link and the lifetime" do
    text = @mail.text_part.body.to_s

    assert_includes text, "Your mcp4mail data export is ready:"
    assert_includes text, @url
    assert_includes text, "The link works for 1 day"
  end

  test "the template is English whatever the locale" do
    mail = I18n.with_locale(:cs) { AccountExportsMailer.ready(@export, @export.raw_token) }

    assert_includes mail.text_part.body.to_s, "Your mcp4mail data export is ready:"
  end
end
