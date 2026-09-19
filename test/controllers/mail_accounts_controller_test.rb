require "test_helper"

class MailAccountsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  def account_params(port:, **overrides)
    { mail_account: { display_name: "Fake", host: "127.0.0.1", port: port, ssl: "0", username: "bob", password: "app-password" }.merge(overrides) }
  end

  test "requires sign-in" do
    get mail_accounts_path
    assert_redirected_to new_session_path
  end

  test "index lists only the signed-in user's mailboxes" do
    sign_in_as @user
    get mail_accounts_path

    assert_response :success
    assert_select "#mail_account_#{mail_accounts(:work).id}"
    assert_select "#mail_account_#{mail_accounts(:personal).id}", count: 0
  end

  test "new offers the provider presets" do
    sign_in_as @user
    get new_mail_account_path

    assert_response :success
    assert_select "option[value=seznam][data-host='imap.seznam.cz'][data-port='993']"
    assert_select "option[value=gmail][data-host='imap.gmail.com']"
  end

  test "create saves the mailbox once the connection test passes and starts a sync" do
    server = FakeImapServer.new.start
    sign_in_as @user

    assert_difference -> { @user.mail_accounts.count } do
      assert_enqueued_with(job: MailAccountSyncJob) do
        post mail_accounts_path, params: account_params(port: server.port)
      end
    end

    assert_redirected_to mail_accounts_path
    account = @user.mail_accounts.order(:created_at).last
    assert_equal "127.0.0.1", account.host
    assert_not account.ssl
    assert account.last_connected_at.present?
  ensure
    server&.stop
  end

  test "create does not save the mailbox when the server rejects the login" do
    server = FakeImapServer.new(login_ok: false).start
    sign_in_as @user

    assert_no_difference -> { MailAccount.count } do
      post mail_accounts_path, params: account_params(port: server.port)
    end

    assert_response :unprocessable_entity
    assert_select "#connection-error", /rejected the username or password/
    assert_no_enqueued_jobs only: MailAccountSyncJob
  ensure
    server&.stop
  end

  test "create reports an unreachable server" do
    server = FakeImapServer.new.start
    port = server.port
    server.stop
    sign_in_as @user

    assert_no_difference -> { MailAccount.count } do
      post mail_accounts_path, params: account_params(port: port)
    end

    assert_select "#connection-error", /could not be reached/
  end

  test "create with invalid fields shows the validation errors before any connection test" do
    sign_in_as @user

    post mail_accounts_path, params: account_params(port: 993, host: "")

    assert_response :unprocessable_entity
    assert_select "#errors", /IMAP server can't be blank/
    assert_select "#connection-error", count: 0
  end

  test "destroy removes the user's own mailbox" do
    sign_in_as @user

    assert_difference -> { MailAccount.count }, -1 do
      delete mail_account_path(mail_accounts(:work))
    end

    assert_redirected_to mail_accounts_path
  end

  test "destroy refuses another user's mailbox" do
    sign_in_as @user

    assert_no_difference -> { MailAccount.count } do
      delete mail_account_path(mail_accounts(:personal))
    end

    assert_response :not_found
  end

  test "index counts today's and this week's calls per mailbox" do
    work = mail_accounts(:work)
    record_event(work, created_at: 2.hours.ago)
    record_event(work, created_at: 3.hours.ago)
    record_event(work, created_at: Time.current.beginning_of_week + 1.minute)
    record_event(work, created_at: 3.weeks.ago)
    record_event(mail_accounts(:personal), user: users(:two))

    sign_in_as @user
    get mail_accounts_path

    assert_select "#calls_mail_account_#{work.id}", /today: 2.*this week: 3/
  end

  test "index shows no calls for a mailbox nothing has asked for" do
    sign_in_as @user
    get mail_accounts_path

    assert_select "#calls_mail_account_#{mail_accounts(:work).id}", /today: 0, this week: 0/
  end

  test "activity lists the recent calls with their tool titles, clients and outcomes" do
    work = mail_accounts(:work)
    Hitch::Client.register!(client_id: "client-abc", client_name: "Claude Desktop", redirect_uris: [ "https://example.com/cb" ])
    record_event(work, tool_name: "search_messages", rows_returned: 7, created_at: 5.minutes.ago)
    record_event(work, tool_name: "get_message", outcome: "denied", created_at: 10.minutes.ago)

    sign_in_as @user
    get activity_mail_account_path(work)

    assert_response :success
    assert_select "turbo-frame#activity_mail_account_#{work.id} li", 2
    assert_select "li", /Search messages/
    assert_select "li", /Claude Desktop/
    assert_select "li", /rows: 7/
    assert_select "li span.text-red-700", "denied"
    assert_select "li", /5 minutes ago/
  end

  test "activity shows at most the last twenty calls, newest first" do
    work = mail_accounts(:work)
    25.times { |index| record_event(work, tool_name: "search_messages", rows_returned: index, created_at: index.minutes.ago) }

    sign_in_as @user
    get activity_mail_account_path(work)

    assert_select "li", McpAuditEvent::RECENT_LIMIT
    assert_select "li:first-of-type", /rows: 0/
  end

  test "activity says so when the mailbox has never been called" do
    sign_in_as @user
    get activity_mail_account_path(mail_accounts(:work))

    assert_select "#activity_empty_mail_account_#{mail_accounts(:work).id}"
  end

  test "activity refuses another user's mailbox" do
    sign_in_as @user
    get activity_mail_account_path(mail_accounts(:personal))

    assert_response :not_found
  end

  test "activity requires sign-in" do
    get activity_mail_account_path(mail_accounts(:work))
    assert_redirected_to new_session_path
  end

  private
    def record_event(mail_account, user: @user, tool_name: "search_messages", outcome: "ok", rows_returned: 0, created_at: Time.current)
      McpAuditEvent.create!(
        user:, mail_account_id: mail_account.id, tool_name:, outcome:, rows_returned:,
        client_id: "client-abc", created_at: created_at
      )
    end
end
