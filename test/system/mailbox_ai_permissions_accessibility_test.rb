require "application_system_test_case"
require "axe/api/run"

# The accessibility pass of task #13348 over the "What may the AI do?" boxes
# under the mailbox switch. The findings are written up in
# docs/accessibility/axe-report.md.
class MailboxAiPermissionsAccessibilityTest < ApplicationSystemTestCase
  WCAG_AA = %i[wcag2a wcag2aa wcag21a wcag21aa].freeze
  BLOCKING_IMPACTS = %w[serious critical].freeze
  SWITCH = "Allow the AI to make changes to this mailbox".freeze
  COLUMNS = MailAccount::AI_PERMISSIONS.values.freeze

  test "axe passes on the mailbox index with the switch off and on, in either language" do
    sign_in(users(:one))

    [ false, true ].each do |writable|
      mail_accounts(:work).update!(writable:)
      %i[en cs].each do |locale|
        visit mail_accounts_url(locale:)
        assert_selector "##{fieldset_id}", visible: writable

        audit = Axe::Core.new(page).call(Axe::API::Run.new.according_to(*WCAG_AA))
        blocking = audit.results.violations.select { |rule| BLOCKING_IMPACTS.include?(rule.impact.to_s) }
        assert_empty blocking.map { |rule| "#{rule.impact} #{rule.id}: #{rule.help}" },
                     "switch #{writable ? 'on' : 'off'}, #{locale}: axe found blocking violations\n#{audit.failure_message}"
      end
    end
  end

  test "each box has a real label, the group a legend, and the folded group is out of the accessibility tree" do
    mail_accounts(:work).update!(writable: true)
    sign_in(users(:one))
    visit mail_accounts_url

    within "##{fieldset_id}" do
      assert_selector "legend", text: /\AWhat may the AI do\?\z/i
      COLUMNS.each { |column| assert_selector "label[for='#{control_id(column)}'] input##{control_id(column)}[type=checkbox]" }
    end

    uncheck SWITCH
    assert_text "Work is read-only again"
    assert_equal "none", page.evaluate_script("getComputedStyle(document.getElementById('#{fieldset_id}')).display"),
                 "the folded group must be display: none, not just invisible, so a screen reader skips it"
    focus control_id(:writable_switch)
    page.send_keys(:tab)
    assert_not_includes COLUMNS.map { control_id(it) }, active_id, "Tab must skip the folded boxes"
  end

  test "the keyboard walks the switch, then each box in order, and keeps its place across the save" do
    work = mail_accounts(:work)
    sign_in(users(:one))
    visit mail_accounts_url

    focus control_id(:writable_switch)
    page.send_keys(:space)
    assert_text "The AI can now make changes to Work."
    assert_equal control_id(:writable_switch), active_id, "the switch keeps focus after the redirect"

    COLUMNS.each do |column|
      page.send_keys(:tab)
      assert_equal control_id(column), active_id, "Tab reaches #{column} next"
    end

    page.send_keys(:space)
    assert_text "Saved what the AI may do in Work."
    assert_not work.reload.public_send(COLUMNS.last)
    assert_equal control_id(COLUMNS.last), active_id, "the box keeps focus after the redirect"
  end

  private
    def fieldset_id = control_id(:ai_permissions)

    def control_id(suffix) = ActionView::RecordIdentifier.dom_id(mail_accounts(:work), suffix)

    def focus(id) = page.evaluate_script("document.getElementById('#{id}').focus()")

    def active_id = page.evaluate_script("document.activeElement.id")

    def sign_in(user)
      visit new_session_url
      fill_in placeholder: "Enter your email address", with: user.email_address
      fill_in placeholder: "Enter your password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end
end
