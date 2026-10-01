require "test_helper"

class Imap::GmailWriteTest < ActiveSupport::TestCase
  setup do
    @mailboxes = { "Work" => { uidvalidity: 42, messages: [] } }
    @server = FakeImapServer.new(gmail: true, mailboxes: @mailboxes).start
    @server.add_gmail_message(labels: %w[INBOX Work], message_id: "<one@example.com>", envelope: { subject: "Labelled twice" })
    @server.add_gmail_message(labels: [], message_id: "<archived@example.com>", envelope: { subject: "Archived" })
    @account = users(:one).mail_accounts.create!(
      host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password", writable: true
    )
    Imap::MessageSync.call(@account)
  end

  teardown { @server&.stop }

  def row(subject, folder)
    @account.mail_messages.joins(:mail_folder).find_by(subject:, mail_folders: { name: folder })
  end

  def folders_of(subject)
    @account.mail_messages.where(subject:).joins(:mail_folder).order("mail_folders.name").pluck("mail_folders.name")
  end

  def server_folders_of(message_id)
    @mailboxes.select { |_, box| box[:messages].any? { |m| m.dig(:envelope, :message_id) == message_id } }.keys.sort
  end

  test "moving a label to All Mail removes only that label, on the server and in the index" do
    Imap::MessageMover.call(row("Labelled twice", "Work"), to: "[Gmail]/All Mail")

    assert_equal %w[INBOX [Gmail]/All\ Mail], server_folders_of("<one@example.com>")
    assert_equal %w[INBOX], folders_of("Labelled twice")
  end

  test "moving to a label the message already has leaves one row in it" do
    Imap::MessageMover.call(row("Labelled twice", "Work"), to: "INBOX")

    assert_equal %w[INBOX], folders_of("Labelled twice")
    assert_equal %w[INBOX [Gmail]/All\ Mail], server_folders_of("<one@example.com>")
  end

  test "labelling an archived message replaces its All Mail row" do
    Imap::MessageMover.call(row("Archived", "[Gmail]/All Mail"), to: "Work")

    assert_equal %w[Work], folders_of("Archived")
    assert_includes server_folders_of("<archived@example.com>"), "[Gmail]/All Mail"
  end

  test "trash takes the message out of every label and indexes it only in Trash" do
    Imap::MessageMover.trash(row("Labelled twice", "INBOX"))

    assert_equal [ "[Gmail]/Trash" ], server_folders_of("<one@example.com>")
    assert_equal [ "[Gmail]/Trash" ], folders_of("Labelled twice")
  end

  test "trashing an archived message leaves it only in Trash" do
    Imap::MessageMover.trash(row("Archived", "[Gmail]/All Mail"))

    assert_equal [ "[Gmail]/Trash" ], server_folders_of("<archived@example.com>")
    assert_equal [ "[Gmail]/Trash" ], folders_of("Archived")
  end

  test "starring applies to the message under every label" do
    flags = Imap::FlagSetter.call(row("Labelled twice", "INBOX"), flagged: true)

    assert_includes flags, "Flagged"
    assert_equal [ [ "Flagged" ] ] * 2, @account.mail_messages.where(subject: "Labelled twice").pluck(:flags).map { |f| f & [ "Flagged" ] }
    work = @mailboxes["Work"][:messages].first
    assert_includes work[:flags], "\\Flagged"
  end
end
