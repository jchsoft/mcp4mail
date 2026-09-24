require "test_helper"

# The switch is the per-mailbox "Allow the AI to make changes" control on
# mail_accounts/index (and any future on/off form control). What the partial
# must do, in this exact shape:
#
# - Render a real <input type="checkbox"> so form.check_box still emits the
#   `0` hidden field the controller needs to turn the switch off, AND so the
#   controller test keeps asserting on [role=switch][checked] / :not([checked]).
# - Carry role="switch" (not checkbox) so assistive tech reads "switch", not
#   "checkbox", and a screen reader does not have to disambiguate a labelled
#   binary control.
# - Stay free of per-component focus styles — the global two-tone ring in
#   application.css draws AROUND the visible input, which is what requires
#   the input itself to be the visible track.
# - Stay free of any default-palette hue (GUIDELINES §6): off / on are the
#   surface-hover / ink tokens the rest of the system uses.
class SharedSwitchTest < ActionView::TestCase
  test "renders a real checkbox with role=switch, tied to its label" do
    render_switch

    assert_select "input[type=checkbox][role=switch]#mail_account_writable"
    assert_select "label[for=mail_account_writable]", "Allow the AI to make changes"
  end

  test "passes the unchecked-value hidden field the controller expects" do
    render_switch

    assert_select "input[type=hidden][name='mail_account[writable]'][value='0']"
  end

  test "reflects the record's current value" do
    render_switch MailAccount.new(writable: true)

    assert_select "input[type=checkbox][role=switch][checked]#mail_account_writable"
  end

  test "an off switch is unchecked and carries no checked attribute" do
    render_switch MailAccount.new(writable: false)

    assert_select "input[type=checkbox][role=switch]#mail_account_writable:not([checked])"
  end

  test "honours a caller-supplied id and data attributes" do
    render_switch input: { id: "my-switch", data: { action: "auto-submit#submit" } }

    assert_select "input#my-switch[data-action='auto-submit#submit']"
    assert_select "label[for=my-switch]"
  end

  test "uses the surface-hover off fill and the ink on fill" do
    render_switch

    assert_select "input[type=checkbox].bg-surface-hover.checked\\:bg-ink"
  end

  test "never sets a local focus style or an off-palette colour" do
    render_switch

    refute_match(/focus:|outline:|focus-visible:|ring-/, rendered)
    refute_match(/\b(?:slate|gray|grey|zinc|neutral|stone|red|orange|amber|yellow|lime|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d+\b/, rendered)
  end

  private
    def render_switch(record = MailAccount.new(writable: false), **locals)
      render inline: <<~ERB, locals: { record:, locals: }
        <%= form_with model: record, url: "/mail_accounts" do |form| %>
          <%= render "shared/switch", form: form, attribute: :writable, label: "Allow the AI to make changes", **locals %>
        <% end %>
      ERB
    end
end
