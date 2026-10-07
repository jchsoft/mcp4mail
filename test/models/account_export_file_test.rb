require "test_helper"

class AccountExportFileTest < ActiveSupport::TestCase
  test "start! keeps only the digest of the raw token" do
    export = AccountExportFile.start!(users(:one))

    assert_predicate export.raw_token, :present?
    assert_equal AccountExportFile.digest(export.raw_token), export.token_digest
    assert_not_includes export.reload.attributes.values, export.raw_token
    assert_in_delta AccountExportFile::EXPIRES_IN.from_now, export.expires_at, 5.seconds
  end

  test "find_ready needs a live row with a payload and the right token" do
    export = AccountExportFile.start!(users(:one))
    assert_nil AccountExportFile.find_ready(export.raw_token), "no payload yet"

    export.store!("{}")
    assert_equal export, AccountExportFile.find_ready(export.raw_token)
    assert_nil AccountExportFile.find_ready("nope")
    assert_nil AccountExportFile.find_ready(nil)
    assert_nil AccountExportFile.find_ready("")

    export.update!(expires_at: 1.minute.ago)
    assert_nil AccountExportFile.find_ready(export.raw_token)
  end

  test "sweep deletes only expired rows" do
    live = AccountExportFile.start!(users(:one))
    expired = AccountExportFile.start!(users(:one)).tap { |e| e.update!(expires_at: 1.hour.ago) }

    assert_difference -> { AccountExportFile.count }, -1 do
      AccountExportFile.sweep
    end
    assert AccountExportFile.exists?(live.id)
    assert_not AccountExportFile.exists?(expired.id)
  end
end
