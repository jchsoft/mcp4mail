class CreateOutgoingMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :outgoing_messages do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :mail_account, null: false, foreign_key: { on_delete: :cascade }
      t.string :client_id, null: false
      t.string :state, null: false, default: "pending"
      t.jsonb :to_addresses, null: false, default: []
      t.jsonb :cc_addresses, null: false, default: []
      t.jsonb :bcc_addresses, null: false, default: []
      t.text :subject
      t.text :body
      t.text :in_reply_to
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :sent_at
      t.timestamps
    end

    add_index :outgoing_messages, :token_digest, unique: true
    add_index :outgoing_messages, [ :mail_account_id, :state ]
  end
end
