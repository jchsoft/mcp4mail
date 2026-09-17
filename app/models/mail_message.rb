# Headers of one message, indexed locally so searching never goes through IMAP SEARCH.
# Bodies are not stored. A row is identified by folder + UIDVALIDITY + UID.
class MailMessage < ApplicationRecord
  belongs_to :mail_account
  belongs_to :mail_folder

  scope :for_user, ->(user) { where(mail_account_id: user.mail_accounts.select(:id)) }

  # Every word of the query has to appear in the subject or among the participants.
  # Case and diacritics are ignored ("zluty" finds "Žlutý").
  scope :search, ->(query) {
    normalize_search_text(query).split.uniq.inject(all) do |relation, term|
      relation.where("mail_messages.search_text LIKE ?", "%#{sanitize_sql_like(term)}%")
    end
  }

  def self.normalize_search_text(text)
    text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.squish
  end

  def self.build_search_text(subject:, from_name:, from_address:, to_addresses:, cc_addresses:)
    participants = [ { "name" => from_name, "address" => from_address }, *to_addresses, *cc_addresses ]
    parts = [ subject, *participants.flat_map { |p| [ p["name"], p["address"] ] } ]
    normalize_search_text(parts.compact_blank.join(" "))
  end
end
