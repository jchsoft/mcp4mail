require "test_helper"

class MailAccountTest < ActiveSupport::TestCase
  SECRET = "s3cret-app-password-do-not-leak"

  def build_account(**attributes)
    users(:two).mail_accounts.new(host: "imap.example.org", username: "bob", password: SECRET, **attributes)
  end

  test "defaults to IMAPS on port 993 and the INBOX" do
    account = build_account

    assert account.valid?
    assert_equal 993, account.port
    assert account.ssl
    assert_equal "INBOX", account.default_folder
  end

  test "normalises host and username" do
    account = build_account(host: "  IMAP.Example.ORG \n", username: " bob ")

    assert_equal "imap.example.org", account.host
    assert_equal "bob", account.username
  end

  test "validates host, port, username and password" do
    assert_not build_account(host: "  ").valid?
    assert_not build_account(username: "").valid?
    assert_not build_account(password: "").valid?
    assert_not build_account(port: nil).valid?
    assert_not build_account(port: 0).valid?
    assert_not build_account(port: 65_536).valid?
    assert_not build_account(port: 99.5).valid?
    assert build_account(port: 143, ssl: false).valid?
  end

  test "stores the password encrypted and non-deterministically" do
    first = build_account.tap(&:save!)
    second = build_account.tap(&:save!)

    raw = MailAccount.connection.select_values(
      MailAccount.where(id: [ first.id, second.id ]).order(:id).select(:password).to_sql
    )
    raw.each { |ciphertext| assert_not_includes ciphertext, SECRET }
    assert_not_equal raw.first, raw.second

    assert_equal SECRET, MailAccount.find(first.id).password
    assert_not MailAccount.type_for_attribute(:password).deterministic?
  end

  test "reads fixture passwords through encryption" do
    assert_equal "fixture-app-password", mail_accounts(:work).password
  end

  test "never exposes the password through inspect, serializers or errors" do
    account = build_account.tap(&:save!)

    assert_not_includes account.inspect, SECRET
    assert_includes account.inspect, "[FILTERED]"
    assert_not_includes account.to_json, SECRET
    assert_not account.as_json.key?("password")
    assert_not account.serializable_hash(only: [ :password ]).key?("password")
    assert_not_includes users(:two).to_json(include: :mail_accounts), SECRET

    account.host = ""
    error = assert_raises(ActiveRecord::RecordInvalid) { account.save! }
    assert_not_includes error.message, SECRET
    assert_not_includes account.errors.full_messages.join, SECRET
  end

  test "never writes the password to the log" do
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    logger.level = :debug

    ActiveRecord::Base.logger, previous = logger, ActiveRecord::Base.logger
    begin
      account = build_account.tap(&:save!)
      account.update!(password: "#{SECRET}-rotated")
      MailAccount.find(account.id).password
      MailAccount.where(username: "bob").to_a
    ensure
      ActiveRecord::Base.logger = previous
    end

    assert_match(/INSERT INTO "mail_accounts"/, log.string)
    assert_not_includes log.string, SECRET
  end

  test "filters the password from request parameter logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("mail_account" => { "password" => SECRET })["mail_account"]["password"]
  end
end
