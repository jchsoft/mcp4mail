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
end
