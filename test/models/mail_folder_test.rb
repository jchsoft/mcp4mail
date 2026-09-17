require "test_helper"

class MailFolderTest < ActiveSupport::TestCase
  setup do
    @folder = mail_accounts(:work).mail_folders.create!(name: "INBOX")
  end

  def add_message(uid)
    @folder.mail_messages.create!(mail_account: @folder.mail_account, uidvalidity: @folder.uidvalidity, uid: uid)
  end

  test "adopting the first UIDVALIDITY is not a reset" do
    assert_not @folder.adopt_uidvalidity!(10)
    assert_equal 10, @folder.uidvalidity
  end

  test "the same UIDVALIDITY keeps messages and cursor" do
    @folder.adopt_uidvalidity!(10)
    add_message(4)
    @folder.update!(last_synced_uid: 4)

    assert_not @folder.adopt_uidvalidity!(10)
    assert_equal 4, @folder.reload.last_synced_uid
    assert_equal 1, @folder.mail_messages.count
  end

  test "a different UIDVALIDITY drops the folder's messages and rewinds the cursor" do
    @folder.adopt_uidvalidity!(10)
    add_message(4)
    @folder.update!(last_synced_uid: 4)

    assert @folder.adopt_uidvalidity!(11)
    @folder.reload
    assert_equal 11, @folder.uidvalidity
    assert_equal 0, @folder.last_synced_uid
    assert_empty @folder.mail_messages
  end
end
