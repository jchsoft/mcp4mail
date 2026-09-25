require "test_helper"

class MailProviderTest < ActiveSupport::TestCase
  test "presets cover the common providers" do
    assert_equal "imap.seznam.cz", MailProvider.find("seznam").host
    assert_equal "imap.gmail.com", MailProvider.find("gmail").host
    assert_equal "outlook.office365.com", MailProvider.find("outlook").host
    assert_nil MailProvider.find("nope")
  end

  test "every preset has a hint in every locale" do
    I18n.available_locales.each do |locale|
      MailProvider.all.each do |preset|
        assert I18n.exists?("mail_accounts.providers.#{preset.key}", locale), "#{locale}: missing hint for #{preset.key}"
      end
    end
  end

  test "the form offers only presets with a server to fill in" do
    assert_includes MailProvider.selectable.map(&:key), "gmail"
    assert_not_includes MailProvider.selectable.map(&:key), "cpanel"
  end
end
