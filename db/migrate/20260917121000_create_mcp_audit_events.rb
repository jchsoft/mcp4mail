class CreateMcpAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_audit_events do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      # No foreign key: the trail must outlive a deleted account, and a denied call names
      # an account id that may belong to someone else or not exist at all.
      t.bigint :mail_account_id
      t.string :tool_name, null: false
      t.string :outcome, null: false
      t.integer :rows_returned, null: false, default: 0
      t.integer :duration_ms
      t.string :client_id, null: false
      t.string :remote_ip

      t.datetime :created_at, null: false
    end

    add_index :mcp_audit_events, [ :user_id, :created_at ]
    add_index :mcp_audit_events, :mail_account_id
  end
end
