require "test_helper"

class ApplicationLayoutTest < ActionDispatch::IntegrationTest
  test "a signed-in screen sits in the landing shell behind a skip link" do
    sign_in_as users(:one)

    get mail_accounts_path

    assert_response :success
    assert_select "body > a.skip-link:first-child[href='#main']", text: I18n.t("layouts.skip_to_content")
    assert_select "body > header.landing-shell nav[aria-label=?]", I18n.t("nav.label")
    assert_select "body > main#main.landing-shell[tabindex='-1']", count: 1
    assert_select "main.container", count: 0
  end

  test "the flash renders at the top of the shell, as on the public layout" do
    sign_in_as users(:one)

    delete mail_account_path(mail_accounts(:work))
    follow_redirect!

    assert_select "main#main > p#notice:first-child"
  end

  test "a signed-out screen on the same layout gets the same frame" do
    get new_session_path

    assert_select "body > a.skip-link:first-child[href='#main']"
    assert_select "body > main#main.landing-shell"
  end
end
