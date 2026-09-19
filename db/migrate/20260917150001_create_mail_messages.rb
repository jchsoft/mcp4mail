class CreateMailMessages < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :mail_messages do |t|
      t.references :mail_account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :mail_folder, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.bigint :uidvalidity, null: false
      t.bigint :uid, null: false
      t.datetime :date
      t.datetime :internal_date
      t.string :from_name
      t.string :from_address
      t.jsonb :to_addresses, null: false, default: []
      t.jsonb :cc_addresses, null: false, default: []
      t.text :subject
      t.string :message_id
      t.text :in_reply_to
      t.boolean :has_attachments, null: false, default: false
      t.jsonb :attachments, null: false, default: []
      t.bigint :size
      t.string :flags, array: true, null: false, default: []
      # Subject and participants, lowercased with diacritics stripped, for trigram search.
      t.text :search_text, null: false, default: ""
      t.timestamps
    end

    add_index :mail_messages, [ :mail_folder_id, :uidvalidity, :uid ], unique: true
    add_index :mail_messages, [ :mail_account_id, :date ]
    add_index :mail_messages, :message_id
    add_index :mail_messages, :search_text, using: :gin, opclass: :gin_trgm_ops
  end
end
