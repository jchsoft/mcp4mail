class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :mail_accounts, dependent: :destroy
  has_many :mcp_audit_events, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
