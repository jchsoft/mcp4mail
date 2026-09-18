require "mail"

module Imap
  # Re-fetches one message's raw bytes and pulls out a single attachment's decoded body, by its
  # position in a depth-first walk of the MIME tree - the same order MessageHeaders used to
  # build the attachments list get_message hands out, so an index taken from there still points
  # at the right part here.
  class MessageAttachment
    # Mirrors Imap::MessageBody::MessageGone: the folder's UIDVALIDITY has changed or the UID
    # is no longer there, so the id/index pair no longer identifies a real attachment.
    class MessageGone < StandardError; end

    Result = Struct.new(:filename, :content_type, :body, keyword_init: true)

    def self.call(mail_account:, mail_folder:, uid:, uidvalidity:, index:)
      new(mail_account:, mail_folder:, uid:, uidvalidity:, index:).call
    end

    def initialize(mail_account:, mail_folder:, uid:, uidvalidity:, index:)
      @mail_account = mail_account
      @mail_folder = mail_folder
      @uid = uid
      @uidvalidity = uidvalidity
      @index = index
    end

    def call
      raw = Connection.open(mail_account) { |imap| fetch_raw(imap) }
      part = attachments_in(Mail.read_from_string(raw))[index]
      return nil if part.nil?

      Result.new(filename: part.filename, content_type: part.mime_type.to_s.downcase, body: part.body.decoded)
    end

    private
      attr_reader :mail_account, :mail_folder, :uid, :uidvalidity, :index

      def fetch_raw(imap)
        imap.examine(mail_folder.name)
        raise MessageGone unless imap.responses("UIDVALIDITY", &:last) == uidvalidity

        data = imap.uid_fetch(uid, "BODY.PEEK[]")
        raise MessageGone if data.blank?

        data.first.attr["BODY[]"].to_s
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError
        raise MessageGone
      end

      def attachments_in(part)
        return part.parts.flat_map { |child| attachments_in(child) } if part.multipart?

        filename = part.filename
        attachment?(part, filename) ? [ part ] : []
      end

      # Same predicate as Imap::MessageHeaders#attachment?, ported from BODYSTRUCTURE fields to
      # the parsed Mail::Part tree, so the count and order here match what was indexed.
      def attachment?(part, filename)
        disposition = part.header[:content_disposition]&.disposition_type&.upcase.presence
        disposition == "ATTACHMENT" || (filename.present? && disposition != "INLINE")
      end
  end
end
