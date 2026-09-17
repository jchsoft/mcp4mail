# Keys for ActiveRecord Encryption, which protects MailAccount#password.
#
# Production: generate keys with `bin/rails db:encryption:init` and put them either into the
# encrypted credentials (active_record_encryption.*) or into the ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY,
# ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY and ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
# environment variables. Never commit them: this repository is public.
#
# Development and test: when neither is set, keys are derived from the per-machine secret in
# tmp/local_secret.txt, so a fresh checkout works without any shared key.
encryption = Rails.application.config.active_record.encryption

%i[primary_key deterministic_key key_derivation_salt].each do |name|
  value = ENV["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}"].presence
  value ||= Rails.application.credentials.dig(:active_record_encryption, name).presence
  if value.nil? && Rails.env.local?
    value = Rails.application.key_generator.generate_key("active_record_encryption/#{name}", 32).unpack1("H*")
  end

  encryption[name] = value if value
end
