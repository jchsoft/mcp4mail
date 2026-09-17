class CreateMailFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_folders do |t|
      t.references :mail_account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :delimiter
      t.string :special_use
      # UIDVALIDITY the cursor below belongs to. A UID only means something together with it.
      t.bigint :uidvalidity
      # Resume point: every message with a UID up to this one is already in mail_messages.
      t.bigint :last_synced_uid, null: false, default: 0
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end

    add_index :mail_folders, [ :mail_account_id, :name ], unique: true
  end
end
