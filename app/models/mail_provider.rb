# IMAP settings of the providers people actually use, so that "add mailbox" does not
# start with looking up a host name. Each preset has a translated hint under
# mail_accounts.providers.<key> for the step users trip over (IMAP switched off,
# app password required).
class MailProvider
  Preset = Data.define(:key, :name, :host, :port, :ssl)

  PRESETS = [
    Preset.new(key: "seznam", name: "Seznam.cz (Email.cz)", host: "imap.seznam.cz", port: 993, ssl: true),
    Preset.new(key: "gmail", name: "Gmail / Google Workspace", host: "imap.gmail.com", port: 993, ssl: true),
    Preset.new(key: "outlook", name: "Outlook.com / Microsoft 365", host: "outlook.office365.com", port: 993, ssl: true),
    Preset.new(key: "icloud", name: "iCloud Mail", host: "imap.mail.me.com", port: 993, ssl: true),
    Preset.new(key: "yahoo", name: "Yahoo Mail", host: "imap.mail.yahoo.com", port: 993, ssl: true),
    Preset.new(key: "centrum", name: "Centrum.cz", host: "imap.centrum.cz", port: 993, ssl: true),
    Preset.new(key: "volny", name: "Volný.cz", host: "imap.volny.cz", port: 993, ssl: true),
    Preset.new(key: "forpsi", name: "Forpsi", host: "imap.forpsi.com", port: 993, ssl: true),
    Preset.new(key: "active24", name: "Active24", host: "imap.active24.com", port: 993, ssl: true),
    Preset.new(key: "cpanel", name: "cPanel / Plesk / DirectAdmin", host: nil, port: 993, ssl: true)
  ].freeze

  def self.all
    PRESETS
  end

  def self.find(key)
    PRESETS.find { |preset| preset.key == key }
  end
end
