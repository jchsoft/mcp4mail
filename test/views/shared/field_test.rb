require "test_helper"

class SharedFieldTest < ActionView::TestCase
  test "a text control gets a real label tied to it" do
    render_field MailAccount.new, attribute: :host

    assert_select "label[for=mail_account_host]", "IMAP server"
    assert_select "input[type=text]#mail_account_host[name='mail_account[host]']"
  end

  test "email, password and number render their own input types" do
    { email_address: "email", password: "password", port: "number" }.each do |attribute, type|
      render_field MailAccount.new, attribute:, type: type.to_sym

      assert_select "label[for=mail_account_#{attribute}]"
      assert_select "input[type=#{type}]#mail_account_#{attribute}"
    end
  end

  test "a select lists its choices" do
    render_field MailAccount.new, attribute: :tls_mode, type: :select, choices: [ [ "SSL/TLS", "ssl" ], [ "STARTTLS", "starttls" ] ]

    assert_select "label[for=mail_account_tls_mode]"
    assert_select "select#mail_account_tls_mode option", 2
  end

  test "a checkbox puts the label after the box" do
    render_field MailAccount.new, attribute: :ssl, type: :checkbox, label: "Use SSL"

    assert_select "input[type=checkbox]#mail_account_ssl + label[for=mail_account_ssl]", "Use SSL"
  end

  test "a form without a model still labels its control" do
    render inline: <<~ERB
      <%= form_with url: "/session" do |form| %>
        <%= render "shared/field", form: form, attribute: :email_address, type: :email, label: "Email", input: { placeholder: "Enter your email address" } %>
      <% end %>
    ERB

    assert_select "label[for=email_address]", "Email"
    assert_select "input[type=email]#email_address[placeholder='Enter your email address']"
  end

  test "the hint and the inline error describe the control" do
    account = MailAccount.new.tap { |record| record.errors.add(:port, "must be in 1..65535") }
    render_field account, attribute: :port, type: :number, hint: "Usually 993"

    assert_select "#mail_account_port_hint", "Usually 993"
    assert_select "#mail_account_port_error", "must be in 1..65535"
    assert_select "input#mail_account_port[aria-invalid=true][aria-describedby='mail_account_port_hint mail_account_port_error'].border-danger"
  end

  test "a valid field is neither invalid nor described by an error" do
    render_field MailAccount.new, attribute: :host

    assert_select "input#mail_account_host:not([aria-invalid]):not([aria-describedby]).border-field-border"
    assert_select "#mail_account_host_error", 0
  end

  test "the wrapper takes the caller's classes, so a field can be a grid cell" do
    render_field MailAccount.new, attribute: :port, type: :number, class: "my-5 sm:col-span-1"

    assert_select "div.sm\\:col-span-1 input#mail_account_port"
  end

  test "it never sets a local focus style or a gray border" do
    render_field MailAccount.new, attribute: :host, input: { placeholder: "imap.example.com" }

    refute_match(/focus:|outline|gray-400/, rendered)
    assert_select "input.placeholder\\:text-field-placeholder"
  end

  private
    def render_field(record, **locals)
      render inline: <<~ERB, locals: { record:, locals: }
        <%= form_with model: record, url: "/mail_accounts" do |form| %>
          <%= render "shared/field", form: form, **locals %>
        <% end %>
      ERB
    end
end
