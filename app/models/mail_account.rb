# An IMAP mailbox a user has connected. The password is someone else's key to their mail:
# it is encrypted at rest and kept out of logs, inspect output and serialized forms.
class MailAccount < ApplicationRecord
  PORT_RANGE = 1..65_535
  # How the connection is secured: IMAPS from the first byte, a plaintext connection upgraded
  # with STARTTLS, or - only ever typed in by hand, e.g. for a local bridge - no TLS at all.
  TLS_MODES = %w[ ssl starttls none ].freeze

  belongs_to :user
  has_many :mail_folders, dependent: :delete_all
  has_many :mail_messages, dependent: :delete_all
  has_many :mcp_client_sightings, dependent: :delete_all
  has_many :outgoing_messages, dependent: :delete_all

  # Non-deterministic on purpose: nothing ever looks an account up by its password.
  encrypts :password

  # What the user typed on the "add mailbox" form. Detection starts from it, but only the
  # username the server actually accepted is stored.
  attribute :email_address, :string
  # The MailProvider preset picked on the form, for an address whose domain does not give its
  # provider away. Never stored: only the settings it fills in are.
  attribute :provider, :string

  normalizes :host, with: ->(host) { host.strip.downcase }
  normalizes :username, with: ->(username) { username.strip }
  normalizes :default_folder, with: ->(folder) { folder.strip }
  normalizes :email_address, with: ->(email) { email.strip }

  validates :host, presence: true
  validates :port, numericality: { only_integer: true, in: PORT_RANGE }
  validates :username, presence: true
  validates :password, presence: true
  validates :default_folder, presence: true

  def label
    display_name.presence || username
  end

  # The From address of anything this account sends or drafts. Most logins are the address
  # itself; a bare login is completed with the server's host.
  def sender_address
    username.include?("@") ? username : "#{username}@#{host}"
  end

  def tls_mode
    if ssl then "ssl" elsif starttls then "starttls" else "none" end
  end

  # ssl and starttls are two columns but one choice; setting them together keeps them from
  # ever both being on.
  def tls_mode=(mode)
    self.ssl = mode.to_s == "ssl"
    self.starttls = mode.to_s == "starttls"
  end

  def serializable_hash(options = nil)
    super.except("password")
  end
end
