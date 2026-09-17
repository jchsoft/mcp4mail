# An IMAP mailbox a user has connected. The password is someone else's key to their mail:
# it is encrypted at rest and kept out of logs, inspect output and serialized forms.
class MailAccount < ApplicationRecord
  PORT_RANGE = 1..65_535

  belongs_to :user
  has_many :mail_folders, dependent: :delete_all
  has_many :mail_messages, dependent: :delete_all

  # Non-deterministic on purpose: nothing ever looks an account up by its password.
  encrypts :password

  normalizes :host, with: ->(host) { host.strip.downcase }
  normalizes :username, with: ->(username) { username.strip }
  normalizes :default_folder, with: ->(folder) { folder.strip }

  validates :host, presence: true
  validates :port, numericality: { only_integer: true, in: PORT_RANGE }
  validates :username, presence: true
  validates :password, presence: true
  validates :default_folder, presence: true

  def serializable_hash(options = nil)
    super.except("password")
  end
end
