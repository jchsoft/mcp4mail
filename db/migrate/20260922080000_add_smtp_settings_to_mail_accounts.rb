class AddSmtpSettingsToMailAccounts < ActiveRecord::Migration[8.1]
  def change
    # Filled in by Smtp::Autodetect on the first send, so every existing account starts empty.
    add_column :mail_accounts, :smtp_host, :string
    add_column :mail_accounts, :smtp_port, :integer
    add_column :mail_accounts, :smtp_tls, :string
  end
end
