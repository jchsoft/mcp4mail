require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  teardown { AccountExport.synchronous_message_limit_override = nil }

  test "requires sign-in" do
    get account_path
    assert_redirected_to new_session_path

    get export_account_path
    assert_redirected_to new_session_path

    delete account_path
    assert_redirected_to new_session_path
  end

  test "show offers both actions and the confirmation that lists what goes away" do
    sign_in_as @user
    get account_path

    assert_response :success
    assert_select "#download-my-data a[href=?]", export_account_path
    assert_select "#delete-my-account form[action=?]", account_path
    assert_select "#delete-my-account form[data-turbo-confirm*=?]", "passwords"
  end

  test "export streams a JSON file with the user's own data" do
    index_message(mail_accounts(:work), subject: "Invoice 2026")
    McpAuditEvent.create!(user: @user, mail_account: mail_accounts(:work), tool_name: "search_messages",
      outcome: "ok", rows_returned: 1, client_id: "claude")
    sign_in_as @user

    get export_account_path

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/attachment; filename=/, response.headers["Content-Disposition"])

    export = response.parsed_body
    assert_equal @user.email_address, export.dig("user", "email_address")
    assert_equal [ mail_accounts(:work).id ], export["mail_accounts"].map { |account| account["id"] }
    assert_equal [ "Invoice 2026" ], export["messages"].map { |message| message["subject"] }
    assert_equal [ "search_messages" ], export["mcp_audit_events"].map { |event| event["tool_name"] }
  end

  test "export names the AI clients that were granted access" do
    Hitch::AccessToken.create!(principal: @user, client_id: "claude-desktop", client_name: "Claude",
      code_challenge: "a" * 43, code_challenge_method: "S256", scopes: "mcp")
    sign_in_as @user

    get export_account_path

    grant = response.parsed_body["oauth_clients"].sole
    assert_equal [ "claude-desktop", "Claude", "mcp" ], grant.values_at("client_id", "client_name", "scopes")
  end

  test "export leaves out every other user's data" do
    index_message(mail_accounts(:personal), subject: "Not yours")
    McpAuditEvent.create!(user: users(:two), tool_name: "list_mail_accounts", outcome: "ok", client_id: "grok")
    sign_in_as @user

    get export_account_path

    body = response.body
    assert_not_includes body, "Not yours"
    assert_not_includes body, mail_accounts(:personal).host
    assert_not_includes body, "two@example.com"
  end

  # The one thing that must never leave the building, checked by the names of the columns that
  # hold it rather than by the values, so a renamed-but-still-exported secret is still caught.
  test "export contains no password material" do
    index_message(mail_accounts(:work), subject: "Invoice 2026")
    sign_in_as @user

    get export_account_path

    body = response.body
    assert_includes body, mail_accounts(:work).username
    %w[ password password_digest ].each do |attribute|
      assert_not_includes body, attribute
    end
    assert_not_includes body, "fixture-app-password"
    assert_not_includes body, @user.password_digest
  end

  test "an export too large for the request is queued and mailed as a link" do
    index_message(mail_accounts(:work), subject: "Invoice 2026")
    AccountExport.synchronous_message_limit_override = 0
    sign_in_as @user

    assert_difference -> { AccountExportFile.count }, 1 do
      assert_enqueued_with(job: AccountExportJob) do
        get export_account_path
      end
    end

    assert_redirected_to account_path
    export_file = @user.account_export_files.sole
    assert_nil export_file.payload
    assert export_file.expires_at > 23.hours.from_now
  end

  test "destroy removes the user and everything stored for them" do
    index_message(mail_accounts(:work), subject: "Invoice 2026")
    McpAuditEvent.create!(user: @user, tool_name: "list_mail_accounts", outcome: "ok", client_id: "claude")
    sign_in_as @user

    assert_difference -> { User.count }, -1 do
      delete account_path
    end

    assert_redirected_to root_path
    assert_equal 0, MailAccount.where(user_id: @user.id).count
    assert_equal 0, MailMessage.where(mail_account_id: mail_accounts(:work).id).count
    assert_equal 0, MailFolder.where(mail_account_id: mail_accounts(:work).id).count
    assert_equal 0, McpAuditEvent.where(user_id: @user.id).count
    assert_equal 0, Session.where(user_id: @user.id).count
  end

  test "destroy revokes every OAuth grant of the user and leaves other users' grants alone" do
    Hitch::AccessToken.create!(principal: @user, client_id: "claude-desktop", client_name: "Claude",
      code_challenge: "a" * 43, code_challenge_method: "S256")
    other_grant = Hitch::AccessToken.create!(principal: users(:two), client_id: "claude-desktop",
      client_name: "Claude", code_challenge: "b" * 43, code_challenge_method: "S256")
    sign_in_as @user

    delete account_path

    assert_equal 0, Hitch::AccessToken.where(principal_type: "User", principal_id: @user.id.to_s).count
    assert Hitch::AccessToken.exists?(other_grant.id)
  end

  test "destroy signs the person out" do
    sign_in_as @user
    delete account_path

    get mail_accounts_path
    assert_redirected_to new_session_path
  end

  private
    def index_message(mail_account, subject:)
      folder = mail_account.mail_folders.create!(name: "INBOX", uidvalidity: 1)
      folder.mail_messages.create!(mail_account: mail_account, uid: 1, uidvalidity: 1, subject: subject,
        from_address: "sender@example.com", date: Time.current)
    end
end
