# Keys for ActiveRecord Encryption, which protects MailAccount#password.
#
# Each key is looked up, in order, in the ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY,
# ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY and ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT environment
# variables, then in the encrypted credentials (active_record_encryption.*). Generate explicit keys with
# `bin/rails db:encryption:init`. Never commit them: this repository is public.
#
# When neither is set the key is derived from secret_key_base (SECRET_KEY_BASE in production,
# tmp/local_secret.txt in development and test), so an instance that forgot the three variables still
# stores mailbox passwords instead of failing on every "Connect mailbox". The price is that rotating
# SECRET_KEY_BASE, or switching to explicit keys later, makes the stored passwords unreadable.
module ActiveRecordEncryptionKey
  NAMES = %i[primary_key deterministic_key key_derivation_salt].freeze

  def self.call(name, env: ENV, credentials: Rails.application.credentials, key_generator: Rails.application.key_generator)
    env["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}"].presence ||
      credentials.dig(:active_record_encryption, name).presence ||
      key_generator.generate_key("active_record_encryption/#{name}", 32).unpack1("H*")
  end
end

ActiveRecordEncryptionKey::NAMES.each do |name|
  Rails.application.config.active_record.encryption[name] = ActiveRecordEncryptionKey.call(name)
end
