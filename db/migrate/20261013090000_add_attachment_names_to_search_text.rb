# Attachment file names became part of search_text ("the PDFs from X"); rows indexed before that
# get them appended once. Names are lowercased and stripped of diacritics the same way
# MailMessage.normalize_search_text does it for new rows.
class AddAttachmentNamesToSearchText < ActiveRecord::Migration[8.1]
  class MigrationMessage < ActiveRecord::Base
    self.table_name = "mail_messages"
  end

  def up
    MigrationMessage.where(has_attachments: true).find_each do |message|
      names = Array(message.attachments).filter_map { |attachment| attachment["filename"].presence }
      next if names.empty?

      text = [ message.search_text, *names ].join(" ")
      message.update_columns(search_text: text.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.squish)
    end
  end

  def down
    # search_text is derived data; the next sync rewrites it.
  end
end
