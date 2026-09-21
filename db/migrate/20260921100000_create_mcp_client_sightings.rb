class CreateMcpClientSightings < ActiveRecord::Migration[8.1]
  def up
    create_table :mcp_client_sightings do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :mail_account, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :client_id, null: false
      t.string :remote_ip
      t.datetime :first_seen_at, null: false
    end

    # One row per client + address per mailbox. A call without a known address still counts
    # once, hence NULLs compare equal.
    add_index :mcp_client_sightings, [ :mail_account_id, :client_id, :remote_ip ],
      unique: true, nulls_not_distinct: true, name: "index_mcp_client_sightings_uniqueness"
    add_index :mcp_client_sightings, :user_id

    # Clients already seen before this table existed are not new: without the backfill every
    # owner would get an alert for their own long-connected client on the first call after deploy.
    execute <<~SQL
      INSERT INTO mcp_client_sightings (user_id, mail_account_id, client_id, remote_ip, first_seen_at)
      SELECT mail_accounts.user_id, mail_accounts.id, events.client_id, events.remote_ip, MIN(events.created_at)
      FROM mcp_audit_events events
      JOIN mail_accounts ON mail_accounts.id = events.mail_account_id AND mail_accounts.user_id = events.user_id
      WHERE events.outcome <> 'denied'
      GROUP BY mail_accounts.user_id, mail_accounts.id, events.client_id, events.remote_ip
    SQL
  end

  def down
    drop_table :mcp_client_sightings
  end
end
