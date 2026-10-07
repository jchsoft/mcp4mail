require "test_helper"
require_relative "../../support/fake_autodetect_network"

class Smtp::SenderTest < ActiveSupport::TestCase
  include FakeAutodetectNetwork

  class Reports
    attr_reader :errors

    def initialize = @errors = []
    def report(error, handled:, severity:, context:, source: nil) = @errors << [ error, handled, context ]
  end

  setup do
    @sent = { uidvalidity: 7, messages: [] }
    @server = FakeImapServer.new(capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [ { name: "INBOX" }, { name: "Sent", attrs: [ "Sent" ] } ], mailboxes: { "Sent" => @sent }).start
    @account = mail_accounts(:work)
    @account.update!(host: "127.0.0.1", port: @server.port, ssl: false, smtp_host: "smtp.example.com", smtp_port: 465, smtp_tls: "ssl")
    Smtp::Sender.delivery_override = :test
    Mail::TestMailer.deliveries.clear
  end

  teardown do
    Smtp::Sender.delivery_override = nil
    @server.stop
  end

  def build_mail
    Mail.new(from: @account.sender_address, to: "friend@example.net", subject: "Hello", body: "Hi there", date: Time.utc(2026, 1, 2, 3, 4, 5))
  end

  def detected(settings, &block)
    replace_singleton(Smtp::Autodetect, :call, ->(_account, **) { settings }, &block)
  end

  test "delivers and files a Seen copy in the Sent folder" do
    Smtp::Sender.call(@account, build_mail)

    assert_equal 1, Mail::TestMailer.deliveries.size
    assert_equal [ "Seen" ], @sent[:messages].sole[:flags].map { |flag| flag.delete("\\") }
  end

  test "the first send detects the outgoing server and stores it on the account" do
    @account.update_columns(smtp_host: nil, smtp_port: nil, smtp_tls: nil)

    detected(Smtp::Autodetect::Settings.new(host: "out.example.com", port: 587, tls: :starttls)) { Smtp::Sender.call(@account, build_mail) }

    assert_equal [ "out.example.com", 587, "starttls" ], @account.reload.slice(:smtp_host, :smtp_port, :smtp_tls).values
  end

  test "no outgoing server found raises Failed and sends nothing" do
    @account.update_columns(smtp_host: nil)

    error = assert_raises(Smtp::Sender::Failed) { detected(nil) { Smtp::Sender.call(@account, build_mail) } }

    assert_includes error.message, @account.sender_address
    assert_empty Mail::TestMailer.deliveries
  end

  test "without an override the mail goes out over SMTP with the stored settings" do
    Smtp::Sender.delivery_override = nil
    @account.update!(smtp_tls: "starttls", smtp_port: 587)
    mail = build_mail
    settings = nil
    mail.define_singleton_method(:delivery_method) { |_method, options = {}| settings = options }
    mail.define_singleton_method(:deliver!) { nil }

    Smtp::Sender.call(@account, mail)

    assert_equal [ "smtp.example.com", 587, "one@example.com", false, true ],
      settings.values_at(:address, :port, :user_name, :tls, :enable_starttls)
  end

  test "implicit TLS accounts connect over TLS without STARTTLS" do
    settings = Smtp::Sender.new(@account).send(:smtp_settings)

    assert_equal [ true, false, "fixture-app-password" ], settings.values_at(:tls, :enable_starttls, :password)
  end

  test "a transport error becomes Failed" do
    Smtp::Sender.delivery_override = OutgoingMessageRefusal = Class.new do
      def initialize(_settings) = nil
      def deliver!(_mail) = raise(SocketError, "connection refused")
    end

    assert_raises(Smtp::Sender::Failed) { Smtp::Sender.call(@account, build_mail) }
  end

  test "a Sent folder that cannot be reached is reported, and the send still succeeds" do
    @server.stop
    reports = Reports.new
    Rails.error.subscribe(reports)

    Smtp::Sender.call(@account, build_mail)

    assert_equal 1, Mail::TestMailer.deliveries.size
    error, handled, context = reports.errors.sole
    assert_kind_of StandardError, error
    assert handled
    assert_equal({ mail_account_id: @account.id }, context.slice(:mail_account_id))
  ensure
    Rails.error.unsubscribe(reports)
  end

  test "the Sent folder is found by its decoded UTF-7 name when the server has no special-use flag" do
    server = FakeImapServer.new(folders: [ { name: "INBOX" }, { name: "Envoy&AOk-s" } ],
      mailboxes: { "Envoy&AOk-s" => { uidvalidity: 9, messages: [] } }).start
    @account.update!(port: server.port)

    Smtp::Sender.call(@account, build_mail)

    assert_equal 1, server.instance_variable_get(:@mailboxes).fetch("Envoy&AOk-s")[:messages].size
  ensure
    server&.stop
  end

  test "a mailbox with no Sent folder gets one created" do
    server = FakeImapServer.new(folders: [ { name: "INBOX" } ]).start
    @account.update!(port: server.port)

    Smtp::Sender.call(@account, build_mail)

    assert_equal 1, server.instance_variable_get(:@mailboxes).fetch("Sent")[:messages].size
  ensure
    server&.stop
  end
end
