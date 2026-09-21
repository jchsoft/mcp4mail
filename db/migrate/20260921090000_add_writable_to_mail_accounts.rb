class AddWritableToMailAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_accounts, :writable, :boolean, default: false, null: false
  end
end
