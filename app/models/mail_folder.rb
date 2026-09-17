# A folder on a MailAccount together with its sync cursor. IMAP UIDs are only unique within
# one UIDVALIDITY: when the server hands out a new one, every UID we hold for the folder is
# meaningless, so the folder is wiped and imported again from scratch.
class MailFolder < ApplicationRecord
  belongs_to :mail_account
  has_many :mail_messages, dependent: :delete_all

  validates :name, presence: true

  # Adopts the UIDVALIDITY the server just reported. Returns true when the folder had to be
  # reset because it differs from the one the stored UIDs belong to.
  def adopt_uidvalidity!(server_uidvalidity)
    return false if uidvalidity == server_uidvalidity

    reset = uidvalidity.present?
    transaction do
      mail_messages.delete_all if reset
      update!(uidvalidity: server_uidvalidity, last_synced_uid: 0)
    end
    reset
  end
end
