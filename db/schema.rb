# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_21_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "unaccent"

  create_table "account_export_files", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.text "payload"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_account_export_files_on_token_digest", unique: true
    t.index ["user_id"], name: "index_account_export_files_on_user_id"
  end

  create_table "hitch_access_tokens", force: :cascade do |t|
    t.string "authorization_code_digest"
    t.string "client_id", null: false
    t.string "client_name"
    t.string "code_challenge", null: false
    t.string "code_challenge_method", default: "S256", null: false
    t.datetime "code_expires_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "family_expires_at"
    t.string "family_id"
    t.string "principal_id", null: false
    t.string "principal_type", null: false
    t.string "redirect_uri"
    t.datetime "refresh_consumed_at"
    t.datetime "refresh_expires_at"
    t.string "refresh_token_digest"
    t.string "resource_uri"
    t.datetime "revoked_at"
    t.string "scopes", default: "mcp", null: false
    t.string "token_digest"
    t.datetime "updated_at", null: false
    t.index ["authorization_code_digest"], name: "index_hitch_access_tokens_on_authorization_code_digest", unique: true, where: "(authorization_code_digest IS NOT NULL)"
    t.index ["family_id"], name: "index_hitch_access_tokens_on_family_id", where: "(family_id IS NOT NULL)"
    t.index ["principal_type", "principal_id"], name: "index_hitch_access_tokens_on_principal"
    t.index ["refresh_token_digest"], name: "index_hitch_access_tokens_on_refresh_token_digest", unique: true, where: "(refresh_token_digest IS NOT NULL)"
    t.index ["token_digest"], name: "index_hitch_access_tokens_on_token_digest", unique: true, where: "(token_digest IS NOT NULL)"
  end

  create_table "hitch_client_redirect_uris", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "hitch_client_id", null: false
    t.datetime "updated_at", null: false
    t.string "uri", null: false
    t.index ["hitch_client_id", "uri"], name: "index_hitch_client_redirect_uris_on_client_and_uri", unique: true
  end

  create_table "hitch_clients", force: :cascade do |t|
    t.string "application_type"
    t.string "client_id", null: false
    t.string "client_name", null: false
    t.string "client_secret_digest"
    t.datetime "client_secret_issued_at"
    t.datetime "client_secret_rotated_at"
    t.datetime "created_at", null: false
    t.boolean "operator_registered", default: false, null: false
    t.string "token_endpoint_auth_method", default: "none", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_hitch_clients_on_client_id", unique: true
    t.check_constraint "operator_registered = false OR token_endpoint_auth_method::text = 'client_secret_basic'::text", name: "hitch_clients_operator_registration_check"
    t.check_constraint "token_endpoint_auth_method::text = 'none'::text AND client_secret_digest IS NULL AND client_secret_issued_at IS NULL AND client_secret_rotated_at IS NULL OR token_endpoint_auth_method::text = 'client_secret_basic'::text AND client_secret_digest IS NOT NULL AND client_secret_issued_at IS NOT NULL", name: "hitch_clients_secret_consistency_check"
    t.check_constraint "token_endpoint_auth_method::text = ANY (ARRAY['none'::character varying::text, 'client_secret_basic'::character varying::text])", name: "hitch_clients_auth_method_check"
  end

  create_table "hitch_device_grants", force: :cascade do |t|
    t.datetime "approved_at"
    t.string "client_id", null: false
    t.string "client_name"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "denied_at"
    t.string "device_code_digest"
    t.datetime "expires_at", null: false
    t.datetime "last_polled_at"
    t.string "principal_id"
    t.string "principal_type"
    t.string "resource_uri", null: false
    t.string "scopes", default: "mcp", null: false
    t.string "token_endpoint_auth_method", null: false
    t.datetime "updated_at", null: false
    t.string "user_code_digest"
    t.index ["device_code_digest"], name: "index_hitch_device_grants_on_device_code_digest", unique: true, where: "(device_code_digest IS NOT NULL)"
    t.index ["expires_at"], name: "index_hitch_device_grants_on_expires_at"
    t.index ["user_code_digest"], name: "index_hitch_device_grants_on_user_code_digest", unique: true, where: "(user_code_digest IS NOT NULL)"
    t.check_constraint "NOT (approved_at IS NOT NULL AND denied_at IS NOT NULL)", name: "hitch_device_grants_decision_check"
    t.check_constraint "approved_at IS NULL AND principal_type IS NULL AND principal_id IS NULL OR approved_at IS NOT NULL AND principal_type IS NOT NULL AND principal_id IS NOT NULL", name: "hitch_device_grants_principal_check"
    t.check_constraint "consumed_at IS NULL OR approved_at IS NOT NULL", name: "hitch_device_grants_consumption_check"
    t.check_constraint "token_endpoint_auth_method::text = ANY (ARRAY['none'::character varying::text, 'client_secret_basic'::character varying::text])", name: "hitch_device_grants_auth_method_check"
  end

  create_table "mail_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_folder", default: "INBOX", null: false
    t.string "display_name"
    t.string "host", null: false
    t.datetime "last_connected_at"
    t.text "last_error"
    t.text "password", null: false
    t.integer "port", default: 993, null: false
    t.boolean "ssl", default: true, null: false
    t.boolean "starttls", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "username", null: false
    t.boolean "writable", default: false, null: false
    t.index ["user_id"], name: "index_mail_accounts_on_user_id"
  end

  create_table "mail_folders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delimiter"
    t.text "last_error"
    t.datetime "last_synced_at"
    t.bigint "last_synced_uid", default: 0, null: false
    t.bigint "mail_account_id", null: false
    t.string "name", null: false
    t.string "special_use"
    t.bigint "uidvalidity"
    t.datetime "updated_at", null: false
    t.index ["mail_account_id", "name"], name: "index_mail_folders_on_mail_account_id_and_name", unique: true
  end

  create_table "mail_messages", force: :cascade do |t|
    t.jsonb "attachments", default: [], null: false
    t.jsonb "cc_addresses", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "date"
    t.string "flags", default: [], null: false, array: true
    t.string "from_address"
    t.string "from_name"
    t.boolean "has_attachments", default: false, null: false
    t.text "in_reply_to"
    t.datetime "internal_date"
    t.bigint "mail_account_id", null: false
    t.bigint "mail_folder_id", null: false
    t.string "message_id"
    t.text "search_text", default: "", null: false
    t.bigint "size"
    t.text "subject"
    t.jsonb "to_addresses", default: [], null: false
    t.bigint "uid", null: false
    t.bigint "uidvalidity", null: false
    t.datetime "updated_at", null: false
    t.index ["mail_account_id", "date"], name: "index_mail_messages_on_mail_account_id_and_date"
    t.index ["mail_folder_id", "uidvalidity", "uid"], name: "index_mail_messages_on_mail_folder_id_and_uidvalidity_and_uid", unique: true
    t.index ["message_id"], name: "index_mail_messages_on_message_id"
    t.index ["search_text"], name: "index_mail_messages_on_search_text", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "mcp_audit_events", force: :cascade do |t|
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.bigint "mail_account_id"
    t.string "outcome", null: false
    t.string "remote_ip"
    t.integer "rows_returned", default: 0, null: false
    t.string "tool_name", null: false
    t.bigint "user_id", null: false
    t.index ["mail_account_id"], name: "index_mcp_audit_events_on_mail_account_id"
    t.index ["user_id", "created_at"], name: "index_mcp_audit_events_on_user_id_and_created_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "account_export_files", "users", on_delete: :cascade
  add_foreign_key "hitch_client_redirect_uris", "hitch_clients", on_delete: :cascade
  add_foreign_key "mail_accounts", "users"
  add_foreign_key "mail_folders", "mail_accounts", on_delete: :cascade
  add_foreign_key "mail_messages", "mail_accounts", on_delete: :cascade
  add_foreign_key "mail_messages", "mail_folders", on_delete: :cascade
  add_foreign_key "mcp_audit_events", "users", on_delete: :cascade
  add_foreign_key "sessions", "users"
end
