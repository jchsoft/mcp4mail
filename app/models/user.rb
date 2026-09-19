class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :mail_accounts, dependent: :destroy
  has_many :mcp_audit_events, dependent: :delete_all
  has_many :account_export_files, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
