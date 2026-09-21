require "test_helper"

class SharedHeadersTest < ActionView::TestCase
  helper_method :authenticated?, :current_user

  attr_accessor :signed_in_user

  def authenticated? = signed_in_user.present?
  def current_user = signed_in_user

  setup do
    controller.request.path_parameters = { controller: "mail_accounts", action: "index" }
    controller.request.path = "/mail_accounts"
  end

  test "the page header renders the title as an internal-page h1" do
    render "shared/page_header", title: "Mailboxes"

    assert_select "h1.font-heading.text-4xl", text: "Mailboxes"
    assert_select "p", count: 0
  end

  test "the page header shows the lede and the block in the action slot" do
    render "shared/page_header", title: "Mailboxes", lede: "Every mailbox your AI can read." do
      link_to "Add a mailbox", "/mail_accounts/new"
    end

    assert_select "p.text-ink-soft", text: "Every mailbox your AI can read."
    assert_select "a[href='/mail_accounts/new']", text: "Add a mailbox"
  end

  test "the signed-in header carries the links, the identity and a DELETE sign out" do
    self.signed_in_user = users(:one)
    render "shared/app_header"

    assert_select "nav a", text: I18n.t("nav.mailboxes")
    assert_select "nav a", text: I18n.t("nav.connect_ai")
    assert_select "nav a[aria-current=page]", text: I18n.t("nav.mailboxes")
    assert_select "a[href='/account']", text: users(:one).email_address
    assert_select "form[action='/session'] input[name='_method'][value='delete']"
    assert_select "form[action='/session'] button", text: I18n.t("nav.sign_out")
    assert_select "#language-switcher", count: 1
    assert_select "#language-switcher a", text: "CS"
  end

  test "the header keeps to the design tokens and leaves focus to the global ring" do
    self.signed_in_user = users(:one)
    render "shared/app_header"

    refute_match(/\b(?:gray|blue|red|slate|zinc|neutral)-\d/, rendered)
    refute_match(/focus(?:-visible)?:|outline-none/, rendered)
  end

  test "signed out, the header offers sign in and sign up instead" do
    render "shared/app_header"

    assert_select "nav", count: 0
    assert_select "a", text: I18n.t("nav.sign_in")
    assert_select "a", text: I18n.t("nav.sign_up")
    assert_select "form", count: 0
  end
end
