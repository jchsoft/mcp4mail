require "test_helper"

# Guards config/initializers/active_record_encryption.rb. Production once booted without the three
# ACTIVE_RECORD_ENCRYPTION_* variables and every "Connect mailbox" raised
# ActiveRecord::Encryption::Errors::Configuration; a missing key now falls back to one derived from
# secret_key_base in every environment.
class ActiveRecordEncryptionKeyTest < ActiveSupport::TestCase
  KEY_GENERATOR = ActiveSupport::KeyGenerator.new("x" * 64)

  test "the environment variable wins" do
    key = lookup(:primary_key, env: { "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "from-env" },
                               credentials: { active_record_encryption: { primary_key: "from-credentials" } })

    assert_equal "from-env", key
  end

  test "credentials are used when the variable is unset or blank" do
    key = lookup(:deterministic_key, env: { "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "" },
                                     credentials: { active_record_encryption: { deterministic_key: "from-credentials" } })

    assert_equal "from-credentials", key
  end

  test "without either a stable key is derived from secret_key_base" do
    primary = lookup(:primary_key)

    assert_match(/\A\h{64}\z/, primary)
    assert_equal primary, lookup(:primary_key)
    assert_not_equal primary, lookup(:key_derivation_salt)
  end

  test "every key is configured, so a mailbox password can be encrypted" do
    ActiveRecordEncryptionKey::NAMES.each do |name|
      assert_predicate Rails.application.config.active_record.encryption[name], :present?, name
    end
  end

  private
    def lookup(name, env: {}, credentials: {})
      ActiveRecordEncryptionKey.call(name, env: env, credentials: credentials, key_generator: KEY_GENERATOR)
    end
end
