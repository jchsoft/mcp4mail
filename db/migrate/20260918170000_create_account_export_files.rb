class CreateAccountExportFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :account_export_files do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.text :payload
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :account_export_files, :token_digest, unique: true
  end
end
