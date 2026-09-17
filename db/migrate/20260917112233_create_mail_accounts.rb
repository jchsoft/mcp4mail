class CreateMailAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :display_name
      t.string :host, null: false
      t.integer :port, null: false, default: 993
      t.boolean :ssl, null: false, default: true
      t.string :username, null: false
      # Ciphertext from ActiveRecord Encryption, never the plain password.
      t.text :password, null: false
      t.string :default_folder, null: false, default: "INBOX"

      t.timestamps
    end
  end
end
