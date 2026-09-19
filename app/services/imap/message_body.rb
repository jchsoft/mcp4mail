require "mail"

module Imap
  # Fetches and decodes the body of one message at call time - bodies are never stored in the
  # index, so every call is a fresh IMAP round trip. BODY.PEEK[] is used instead of BODY[] so
  # that reading a message through this tool never sets \Seen on the server: a read-only tool
  # must not have that side effect.
  class MessageBody
    # Legacy charset assumed when a part's own charset is missing or does not decode the bytes
    # cleanly - matches MessageHeaders' fallback for undeclared 8-bit headers.
    FALLBACK_CHARSET = "Windows-1250"

    Result = Struct.new(:text, :truncated, keyword_init: true)

    # The folder's UIDVALIDITY has changed since the message was indexed, or the UID is no
    # longer there: the id search_messages handed out does not identify a real message anymore.
    class MessageGone < StandardError; end

    def self.call(mail_account:, mail_folder:, uid:, uidvalidity:, limit:)
      new(mail_account:, mail_folder:, uid:, uidvalidity:, limit:).call
    end

    def initialize(mail_account:, mail_folder:, uid:, uidvalidity:, limit:)
      @mail_account = mail_account
      @mail_folder = mail_folder
      @uid = uid
      @uidvalidity = uidvalidity
      @limit = limit
    end

    def call
      raw = Connection.open(mail_account) { |imap| fetch_raw(imap) }
      text = extract_text(Mail.read_from_string(raw))
      truncated = text.length > limit
      Result.new(text: truncated ? text[0, limit] : text, truncated:)
    end

    private
      attr_reader :mail_account, :mail_folder, :uid, :uidvalidity, :limit

      def fetch_raw(imap)
        imap.examine(mail_folder.name)
        raise MessageGone unless imap.responses("UIDVALIDITY", &:last) == uidvalidity

        data = imap.uid_fetch(uid, "BODY.PEEK[]")
        raise MessageGone if data.blank?

        data.first.attr["BODY[]"].to_s
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError
        raise MessageGone
      end

      def extract_text(mail)
        part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
        return "" if part.nil?

        text = to_utf8(decoded_body(part), part.charset)
        html?(part) ? html_to_text(text) : text
      end

      def html?(part)
        part.mime_type.to_s.casecmp?("text/html")
      end

      # Only the Content-Transfer-Encoding (base64, quoted-printable, ...) is decoded here;
      # charset conversion is done by to_utf8 below, the same way header bytes are decoded in
      # MessageHeaders, rather than trusting the mail gem to survive a mislabelled charset.
      def decoded_body(part)
        part.body.decoded
      rescue Mail::UnknownEncodingType
        part.body.raw_source
      end

      # Declaring UTF-8 and simply being valid UTF-8 are the same test, so a UTF-8 (or blank)
      # charset skips straight to detection below instead of a strict decode that Ruby would
      # no-op on (same source and target encoding never raises, so bad bytes would slip through).
      def to_utf8(bytes, declared_charset)
        raw = bytes.to_s.dup.force_encoding(Encoding::ASCII_8BIT)
        charset = declared_charset.to_s.strip

        if charset.present? && !charset.match?(/\Autf-?8\z/i)
          begin
            return raw.encode(Encoding::UTF_8, charset)
          rescue EncodingError, ArgumentError
            # The declared charset does not actually decode these bytes; fall back to detection.
          end
        end

        utf8 = raw.dup.force_encoding(Encoding::UTF_8)
        return utf8 if utf8.valid_encoding?

        raw.dup.force_encoding(FALLBACK_CHARSET).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      end

      def html_to_text(html)
        doc = Nokogiri::HTML(html)
        doc.css("script, style").each(&:remove)
        doc.css("br").each { |node| node.replace("\n") }
        doc.css("p, div, tr, li, h1, h2, h3, h4, h5, h6").each { |node| node.add_child("\n") }
        doc.text.gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
      end
  end
end
