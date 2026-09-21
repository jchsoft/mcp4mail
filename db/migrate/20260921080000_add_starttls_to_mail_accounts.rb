class AddStarttlsToMailAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_accounts, :starttls, :boolean, default: false, null: false
  end
end
