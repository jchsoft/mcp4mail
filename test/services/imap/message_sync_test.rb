require "test_helper"

class Imap::MessageSyncTest < ActiveSupport::TestCase
  PDF_ATTACHMENT = <<~IMAP.delete("\n")
    (("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 12 1 NIL NIL NIL NIL)
    ("APPLICATION" "PDF" ("NAME" "faktura.pdf") NIL NIL "BASE64" 4000 NIL ("ATTACHMENT" ("FILENAME" "faktura.pdf")) NIL NIL)
     "MIXED" ("BOUNDARY" "b1") NIL NIL NIL)
  IMAP

  setup do
    @mailboxes = {
      "INBOX" => { uidvalidity: 111, messages: [ imap_message(1), imap_message(2), imap_message(5) ] },
      "Sent" => { uidvalidity: 222, messages: [ imap_message(3) ] }
    }
  end

  teardown { @server&.stop }

  def imap_message(uid, **envelope)
    {
      uid: uid,
      flags: [ "\\Seen" ],
      size: 2048,
      envelope: {
        date: "Wed, 16 Sep 2026 09:30:00 +0200",
        subject: "Message #{uid}",
        from: [ [ "Alice", "alice@example.com" ] ],
        to: [ [ nil, "bob@example.com" ] ],
        message_id: "<#{uid}@example.com>"
      }.merge(envelope)
    }
  end

  def start_server(**options)
    @server = FakeImapServer.new(
      capabilities: "IMAP4rev1 SPECIAL-USE",
      folders: [
        { name: "INBOX", attrs: %w[HasNoChildren] },
        { name: "Sent", attrs: %w[HasNoChildren Sent] },
        { name: "[Gmail]", attrs: %w[HasChildren Noselect] }
      ],
      mailboxes: @mailboxes,
      **options
    ).start
  end

  def account
    @account ||= users(:one).mail_accounts.create!(
      host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password"
    )
  end

  def uids_in(folder_name)
    account.mail_messages.joins(:mail_folder).where(mail_folders: { name: folder_name }).order(:uid).pluck(:uid)
  end

  test "imports headers of every selectable folder, keyed by UIDVALIDITY and UID" do
    start_server

    result = Imap::MessageSync.call(account)

    assert_equal 2, result.folders_synced
    assert_equal 4, result.messages_imported
    assert_equal [ 1, 2, 5 ], uids_in("INBOX")
    assert_equal [ 3 ], uids_in("Sent")
    assert_not account.mail_folders.exists?(name: "[Gmail]")

    inbox = account.mail_folders.find_by!(name: "INBOX")
    assert_equal 111, inbox.uidvalidity
    assert_equal 5, inbox.last_synced_uid
    assert inbox.last_synced_at.present?
    assert_equal "sent", account.mail_folders.find_by!(name: "Sent").special_use

    row = inbox.mail_messages.find_by!(uid: 1)
    assert_equal 111, row.uidvalidity
    assert_equal "Message 1", row.subject
    assert_equal "Alice", row.from_name
    assert_equal "alice@example.com", row.from_address
    assert_equal [ { "name" => nil, "address" => "bob@example.com" } ], row.to_addresses
    assert_equal "<1@example.com>", row.message_id
    assert_equal Time.zone.parse("2026-09-16 07:30:00 UTC"), row.date
    assert_equal 2048, row.size
    assert_equal [ "Seen" ], row.flags
    assert_not row.has_attachments
  end

  test "decodes encoded words, raw UTF-8 and attachment metadata" do
    @mailboxes["INBOX"][:messages] = [
      imap_message(1,
        subject: "=?UTF-8?B?xb1sdcWlb3XEjWvDvSBrxa/FiA==?=",
        from: [ [ "Jiří Novák", "Jiri@Example.CZ" ] ],
        in_reply_to: "<parent@example.cz>"
      ).merge(bodystructure: PDF_ATTACHMENT)
    ]
    @mailboxes.delete("Sent")
    start_server

    Imap::MessageSync.call(account)

    row = account.mail_messages.sole
    assert_equal "Žluťoučký kůň", row.subject
    assert_equal "Jiří Novák", row.from_name
    assert_equal "jiri@example.cz", row.from_address
    assert_equal "<parent@example.cz>", row.in_reply_to
    assert row.has_attachments
    assert_equal [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 3000 } ], row.attachments
  end

  test "reads undeclared 8-bit headers as UTF-8, or as Windows-1250 when they are not valid UTF-8" do
    rfc2231 = '("APPLICATION" "PDF" NIL NIL NIL "7BIT" 10 NIL ("ATTACHMENT" ("FILENAME*" "utf-8\'\'P%C5%99%C3%ADloha.pdf")) NIL NIL)'
    @mailboxes["INBOX"][:messages] = [
      imap_message(1, subject: "Plain UTF-8: řeřicha").merge(bodystructure: rfc2231),
      imap_message(2, subject: "Legacy: řeřicha".encode("Windows-1250"))
    ]
    @mailboxes.delete("Sent")
    start_server

    Imap::MessageSync.call(account)

    rows = account.mail_messages.order(:uid)
    assert_equal [ "Plain UTF-8: řeřicha", "Legacy: řeřicha" ], rows.pluck(:subject)
    assert_equal [ "Příloha.pdf" ], rows.first.attachments.pluck("filename")
    assert_equal 1, MailMessage.search("rericha legacy").count
  end

  test "a second run only fetches UIDs above the cursor" do
    start_server
    Imap::MessageSync.call(account)

    @mailboxes["INBOX"][:messages] << imap_message(9)
    @server.fetched_uid_sets.clear
    result = Imap::MessageSync.call(account)

    assert_equal 1, result.messages_imported
    assert_equal [ [ 9 ] ], @server.fetched_uid_sets
    assert_equal [ 1, 2, 5, 9 ], uids_in("INBOX")
    assert_equal 9, account.mail_folders.find_by!(name: "INBOX").last_synced_uid
  end

  test "an unchanged mailbox fetches nothing even though n:* matches the highest UID" do
    start_server
    Imap::MessageSync.call(account)

    # Without UIDNEXT the sync has to ask UID SEARCH 6:*, which the server answers with UID 5.
    @mailboxes.each_value { |mailbox| mailbox[:uidnext] = false }
    @server.fetched_uid_sets.clear
    result = Imap::MessageSync.call(account)

    assert_equal 0, result.messages_imported
    assert_empty @server.fetched_uid_sets
  end

  test "re-imports the folder when the server changes UIDVALIDITY" do
    start_server
    Imap::MessageSync.call(account)
    old_ids = account.mail_messages.pluck(:id)

    @mailboxes["INBOX"] = { uidvalidity: 999, messages: [ imap_message(1, subject: "Different message, same UID") ] }
    result = Imap::MessageSync.call(account)

    assert_equal [ "INBOX" ], result.folders_reset
    inbox = account.mail_folders.find_by!(name: "INBOX")
    assert_equal 999, inbox.uidvalidity
    assert_equal 1, inbox.last_synced_uid
    assert_equal [ "Different message, same UID" ], inbox.mail_messages.pluck(:subject)
    assert_equal [ 999 ], inbox.mail_messages.distinct.pluck(:uidvalidity)
    assert_equal [ 3 ], uids_in("Sent"), "other folders are left alone"
    assert_empty old_ids & inbox.mail_messages.pluck(:id)
  end

  test "resumes from the last committed batch after a crash mid-folder" do
    @mailboxes.delete("Sent")
    @mailboxes["INBOX"][:messages] = (1..5).map { |uid| imap_message(uid) }
    start_server(drop_on_fetch_of: 3)

    assert_raises(StandardError) { Imap::MessageSync.call(account, batch_size: 2) }

    inbox = account.mail_folders.find_by!(name: "INBOX")
    assert_equal 2, inbox.last_synced_uid
    assert_equal [ 1, 2 ], uids_in("INBOX")

    @server.drop_on_fetch_of = nil
    @server.fetched_uid_sets.clear
    Imap::MessageSync.call(account, batch_size: 2)

    assert_equal [ [ 3, 4 ], [ 5 ] ], @server.fetched_uid_sets
    assert_equal [ 1, 2, 3, 4, 5 ], uids_in("INBOX")
    assert_equal 5, inbox.reload.last_synced_uid
  end

  test "a folder that cannot be opened does not stop the others" do
    @mailboxes.delete("Sent")
    start_server

    result = Imap::MessageSync.call(account)

    assert_equal [ "Sent" ], result.folders_failed
    assert_equal [ 1, 2, 5 ], uids_in("INBOX")
    assert_match(/does not exist/, account.mail_folders.find_by!(name: "Sent").last_error)
  end

  test "does not index a folder whose server reports no UIDVALIDITY" do
    @mailboxes["Sent"][:uidvalidity] = nil
    start_server

    result = Imap::MessageSync.call(account)

    assert_equal [ "Sent" ], result.folders_failed
    assert_empty uids_in("Sent")
  end
end
