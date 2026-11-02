# Headers of one message, indexed locally so searching never goes through IMAP SEARCH.
# Bodies are not stored. A row is identified by folder + UIDVALIDITY + UID.
class MailMessage < ApplicationRecord
  belongs_to :mail_account
  belongs_to :mail_folder

  SEARCH_OPERATOR = /\A(?:from|to|cc|bcc|subject):/

  scope :for_user, ->(user) { where(mail_account_id: user.mail_accounts.select(:id)) }

  # Every word of the query has to appear in the subject, among the participants or in an attachment name.
  # Case and diacritics are ignored ("zluty" finds "Žlutý"). Models habitually write Gmail operators, so a
  # leading "from:", "to:", "cc:" or "subject:" is dropped from a word and the word is matched as usual.
  scope :search, ->(query) {
    search_terms(query).inject(all) do |relation, term|
      relation.where("mail_messages.search_text LIKE ?", "%#{sanitize_sql_like(term)}%")
    end
  }

  # Czech endings change (doména / domény / doménu), so a word of 5+ letters loses its last letter and
  # matches as a prefix-stem; shorter words stay exact. See docs/decisions-czech-search.md.
  STEM_MIN_LENGTH = 5

  def self.search_terms(query)
    normalize_search_text(query).split.map { |word| stem(word.sub(SEARCH_OPERATOR, "")) }.compact_blank.uniq
  end

  def self.stem(word)
    word.length >= STEM_MIN_LENGTH ? word[0...-1] : word
  end

  def self.normalize_search_text(text)
    text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.squish
  end

  def self.build_search_text(subject:, from_name:, from_address:, to_addresses:, cc_addresses:, attachment_names: [])
    participants = [ { "name" => from_name, "address" => from_address }, *to_addresses, *cc_addresses ]
    parts = [ subject, *participants.flat_map { |p| [ p["name"], p["address"] ] }, *attachment_names ]
    normalize_search_text(parts.compact_blank.join(" "))
  end

  # "Name <address>", falling back to whichever half of the pair is present.
  def self.display_address(entry)
    name = entry["name"]
    address = entry["address"]
    return address if name.blank?
    return name if address.blank?

    "#{name} <#{address}>"
  end

  def from_display
    self.class.display_address("name" => from_name, "address" => from_address)
  end
end
