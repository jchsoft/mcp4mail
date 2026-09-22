require "test_helper"
require_relative "../support/fake_autodetect_network"

class MailAccountsControllerTest < ActionDispatch::IntegrationTest
  include FakeAutodetectNetwork

  setup { @user = users(:one) }

  # What a person sends who opened "Connection details" and typed the server in.
  def account_params(port:, **overrides)
    { mail_account: { email_address: "bob@example.com", password: "app-password", host: "127.0.0.1", port: port, tls_mode: "none", username: "bob" }.merge(overrides) }
  end

  # What a person sends who only filled in the two visible fields.
  def detection_params(email_address: "bob@example.com", password: "app-password")
    { mail_account: { email_address: email_address, password: password, host: "", port: "993", tls_mode: "ssl", username: "" } }
  end

  def detected(**attributes)
    Imap::Autodetect::Result.new(**attributes)
  end

  def autodetect(result, &block)
    calls = []
    replace_singleton(Imap::Autodetect, :call, ->(**args) { calls << args; result }) { block.call(calls) }
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

  test "new shows only the address and password, with the connection details closed" do
    sign_in_as @user
    get new_mail_account_path

    assert_response :success
    assert_select "input[type=email][name='mail_account[email_address]'][required]"
    assert_select "input[type=password][name='mail_account[password]'][required]"
    assert_select "details#connection-details:not([open])"
    assert_select "details#connection-details input[required]", count: 0
    assert_select "details#connection-details select[name='mail_account[tls_mode]'] option", 3
    assert_select "input[type=submit][value=Connect][data-turbo-submits-with]"
  end

  test "create detects the server settings, saves them and starts a sync" do
    sign_in_as @user

    autodetect(detected(host: "imap.example.com", port: 143, tls: :starttls, username: "bob", source: :srv)) do |calls|
      assert_difference -> { @user.mail_accounts.count } do
        assert_enqueued_with(job: MailAccountSyncJob) do
          post mail_accounts_path, params: detection_params
        end
      end

      assert_equal [ { email: "bob@example.com", password: "app-password" } ], calls
    end

    assert_redirected_to mail_accounts_path
    assert_equal "Connected bob@example.com. Its messages are being indexed in the background.", flash[:notice]
    account = @user.mail_accounts.order(:created_at).last
    assert_equal [ "imap.example.com", 143, "bob" ], [ account.host, account.port, account.username ]
    assert_equal "starttls", account.tls_mode
    assert account.last_connected_at.present?
  end

  test "create re-renders with the connection details open when detection fails" do
    sign_in_as @user

    autodetect(detected(reason: :no_server_found)) do
      assert_no_difference -> { MailAccount.count } do
        post mail_accounts_path, params: detection_params(email_address: "bob@nowhere.example")
      end
    end

    assert_response :unprocessable_entity
    assert_select "#detection-error", /We could not find a mail server for nowhere.example/
    assert_select "details#connection-details[open]"
    assert_select "input[name='mail_account[email_address]'][value='bob@nowhere.example']"
    assert_select "input[name='mail_account[username]'][value='bob@nowhere.example']"
    assert_no_enqueued_jobs only: MailAccountSyncJob
  end

  test "create reports a refused password from detection" do
    sign_in_as @user

    autodetect(detected(reason: :auth_failed, raw_response: "[AUTHENTICATIONFAILED] nope")) do
      post mail_accounts_path, params: detection_params
    end

    assert_response :unprocessable_entity
    assert_select "#detection-error", /The server refused the password/
  end

  test "create links the matching guide when the detected provider has one" do
    sign_in_as @user

    autodetect(detected(reason: :auth_failed, raw_response: "[AUTHENTICATIONFAILED] nope")) do
      post mail_accounts_path, params: detection_params(email_address: "bob@icloud.com")
    end

    assert_response :unprocessable_entity
    assert_select "#detection-error a[href='#{guide_path(:icloud)}'][target=_blank]", "Show me how"
  end

  test "create links the guides index when the detected provider has no guide" do
    sign_in_as @user

    autodetect(detected(reason: :no_server_found)) do
      post mail_accounts_path, params: detection_params(email_address: "bob@nowhere.example")
    end

    assert_response :unprocessable_entity
    assert_select "#detection-error a[href='#{guides_path}'][target=_blank]", "Show me how"
  end

  test "create does not run detection without a usable address" do
    sign_in_as @user

    autodetect(detected(reason: :no_server_found)) do |calls|
      post mail_accounts_path, params: detection_params(email_address: "not-an-address")
      assert_empty calls
    end

    assert_response :unprocessable_entity
    assert_select "#errors", /Email address is invalid/
    assert_select "#detection-error", count: 0
  end

  test "create with the server typed in skips detection and tests the login" do
    server = FakeImapServer.new.start
    sign_in_as @user

    autodetect(detected(reason: :no_server_found)) do |calls|
      post mail_accounts_path, params: account_params(port: server.port)
      assert_empty calls
    end

    assert_redirected_to mail_accounts_path
    assert_equal "127.0.0.1", @user.mail_accounts.order(:created_at).last.host
  ensure
    server&.stop
  end

  test "create with manual settings saves the mailbox once the connection test passes and starts a sync" do
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

  test "create with invalid manual settings shows the validation errors before any connection test" do
    sign_in_as @user

    post mail_accounts_path, params: account_params(port: 0)

    assert_response :unprocessable_entity
    assert_select "#errors", /Port must be in/
    assert_select "details#connection-details[open]"
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

  test "index shows the allow-changes switch off for a new mailbox" do
    sign_in_as @user
    get mail_accounts_path

    assert_select "#writable_switch_mail_account_#{mail_accounts(:work).id}[role=switch]:not([checked])"
    assert_select "#writable_mail_account_#{mail_accounts(:work).id}", /Off: the AI can only read and search/
  end

  test "update switches changes on and off for the user's own mailbox" do
    sign_in_as @user
    account = mail_accounts(:work)

    patch mail_account_path(account), params: { mail_account: { writable: "1" } }
    assert_redirected_to mail_accounts_path
    assert account.reload.writable?
    follow_redirect!
    assert_select "#writable_switch_mail_account_#{account.id}[checked]"

    patch mail_account_path(account), params: { mail_account: { writable: "0" } }
    assert_not account.reload.writable?
  end

  test "update changes nothing but the switch" do
    sign_in_as @user
    account = mail_accounts(:work)

    patch mail_account_path(account), params: { mail_account: { writable: "1", host: "evil.example.com" } }

    assert_equal "imap.example.com", account.reload.host
  end

  test "update refuses another user's mailbox" do
    sign_in_as @user

    patch mail_account_path(mail_accounts(:personal)), params: { mail_account: { writable: "1" } }

    assert_response :not_found
    assert_not mail_accounts(:personal).reload.writable?
  end

  test "update requires sign-in" do
    patch mail_account_path(mail_accounts(:work)), params: { mail_account: { writable: "1" } }

    assert_redirected_to new_session_path
    assert_not mail_accounts(:work).reload.writable?
  end

  test "index counts today's and this week's calls per mailbox" do
    travel_to Time.zone.local(2026, 9, 23, 12, 0) # a Wednesday noon, so "start of week" is never today
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
