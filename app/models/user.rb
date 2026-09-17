class User < ApplicationRecord
  has_many :mail_accounts, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
end
