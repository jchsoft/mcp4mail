# Gmail lists one message in every label folder, in All Mail and in the virtual Important and
# Starred views, so accounts synced before Imap::MessageSync knew about it hold each message
# two or three times. X-GM-MSGID is what tells those copies apart from distinct messages.
class AddGmMsgidToMailMessages < ActiveRecord::Migration[8.1]
  GMAIL_HOSTS = %w[imap.gmail.com imap.googlemail.com].freeze

  def up
    add_column :mail_messages, :gm_msgid, :bigint
    add_index :mail_messages, %i[mail_account_id gm_msgid], where: "gm_msgid IS NOT NULL"

    # The duplicates already indexed carry no X-GM-MSGID to dedupe by, so the index of every
    # Gmail account is dropped and the next sync rebuilds it, each message once.
    gmail_accounts = "SELECT id FROM mail_accounts WHERE lower(host) IN (#{GMAIL_HOSTS.map { |host| connection.quote(host) }.join(", ")})"
    execute "DELETE FROM mail_messages WHERE mail_account_id IN (#{gmail_accounts})"
    execute "DELETE FROM mail_folders WHERE mail_account_id IN (#{gmail_accounts})"
  end

  def down
    remove_index :mail_messages, %i[mail_account_id gm_msgid]
    remove_column :mail_messages, :gm_msgid
  end
end
