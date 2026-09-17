class AddConnectionStatusToMailAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_accounts, :last_connected_at, :datetime
    add_column :mail_accounts, :last_error, :text
  end
end
