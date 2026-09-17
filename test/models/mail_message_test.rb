require "test_helper"

class MailMessageTest < ActiveSupport::TestCase
  def index_message(account, uid:, subject:, from_name: nil, from_address: "someone@example.com", to: [])
    folder = account.mail_folders.find_or_create_by!(name: "INBOX") { |f| f.uidvalidity = 1 }
    account.mail_messages.create!(
      mail_folder: folder, uidvalidity: folder.uidvalidity, uid: uid, subject: subject,
      from_name: from_name, from_address: from_address, to_addresses: to,
      search_text: MailMessage.build_search_text(
        subject: subject, from_name: from_name, from_address: from_address, to_addresses: to, cc_addresses: []
      )
    )
  end

  test "search ignores case and diacritics and matches subject or participants" do
    invoice = index_message(mail_accounts(:work), uid: 1, subject: "Faktura za září", from_name: "Žlutý Kůň s.r.o.")
    other = index_message(mail_accounts(:work), uid: 2, subject: "Lunch", to: [ { "name" => "Petr Dvořák", "address" => "petr@example.cz" } ])

    assert_equal [ invoice ], MailMessage.search("FAKTURA zari").to_a
    assert_equal [ invoice ], MailMessage.search("zluty kun").to_a
    assert_equal [ other ], MailMessage.search("dvorak").to_a
    assert_equal [ other ], MailMessage.search("petr@example").to_a
    assert_empty MailMessage.search("faktura dvorak")
  end

  test "search treats LIKE wildcards literally" do
    index_message(mail_accounts(:work), uid: 1, subject: "Sleva 50%")
    index_message(mail_accounts(:work), uid: 2, subject: "Sleva 500")

    assert_equal [ "Sleva 50%" ], MailMessage.search("50%").pluck(:subject)
  end

  test "for_user spans all of the user's accounts and nobody else's in one query" do
    second_account = users(:one).mail_accounts.create!(host: "imap.example.org", username: "one", password: "x")
    mine = [ index_message(mail_accounts(:work), uid: 1, subject: "Faktura A"), index_message(second_account, uid: 1, subject: "Faktura B") ]
    index_message(mail_accounts(:personal), uid: 1, subject: "Faktura C")

    assert_equal mine.sort, MailMessage.for_user(users(:one)).search("faktura").to_a.sort
  end

  test "the same UID may exist under a different UIDVALIDITY but not twice under one" do
    message = index_message(mail_accounts(:work), uid: 7, subject: "One")

    assert_raises(ActiveRecord::RecordNotUnique) do
      message.dup.save!
    end

    copy = message.dup
    copy.uidvalidity = 2
    assert copy.save!
  end
end
