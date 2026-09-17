module Imap
  # Turns one UID FETCH response (ENVELOPE, BODYSTRUCTURE, FLAGS, ...) into the attributes of
  # a MailMessage row. Header values arrive as raw bytes: RFC 2047 encoded words, plain UTF-8,
  # or - from older Czech mailers - undeclared Windows-1250, and all of them end up as UTF-8.
  class MessageHeaders
    FETCH_ATTRS = %w[UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODYSTRUCTURE].freeze

    # Legacy charset assumed for 8-bit header bytes that are not valid UTF-8.
    FALLBACK_CHARSET = "Windows-1250"

    def self.attributes(fetch_data)
      new(fetch_data).attributes
    end

    def initialize(fetch_data)
      @fetch_data = fetch_data
    end

    def attributes
      envelope = fetch_data.envelope
      from = addresses(envelope&.from).first || {}
      to = addresses(envelope&.to)
      cc = addresses(envelope&.cc)
      subject = decode(envelope&.subject)
      attachments = attachments_in(fetch_data.bodystructure)

      {
        uid: fetch_data.uid,
        internal_date: fetch_data.internaldate,
        date: parse_date(envelope&.date) || fetch_data.internaldate,
        from_name: from["name"],
        from_address: from["address"],
        to_addresses: to,
        cc_addresses: cc,
        subject: subject,
        message_id: clean(envelope&.message_id),
        in_reply_to: clean(envelope&.in_reply_to),
        has_attachments: attachments.any?,
        attachments: attachments,
        size: fetch_data.rfc822_size,
        flags: Array(fetch_data.flags).map(&:to_s),
        search_text: MailMessage.build_search_text(
          subject: subject, from_name: from["name"], from_address: from["address"],
          to_addresses: to, cc_addresses: cc
        )
      }
    end

    private

    attr_reader :fetch_data

    def addresses(list)
      Array(list).filter_map do |address|
        # Group syntax ("undisclosed-recipients:;") shows up as entries without a host.
        next if address.mailbox.blank? || address.host.blank?

        { "name" => decode(address.name).presence, "address" => clean("#{address.mailbox}@#{address.host}").downcase }
      end
    end

    def decode(value)
      return nil if value.nil?

      text = to_utf8(value)
      to_utf8(Mail::Encodings.value_decode(text)).strip
    rescue StandardError
      text&.strip
    end

    def clean(value)
      value.nil? ? nil : to_utf8(value).strip.presence
    end

    def to_utf8(value)
      text = value.dup.force_encoding(Encoding::UTF_8)
      return text if text.valid_encoding?

      value.dup.force_encoding(FALLBACK_CHARSET).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    def parse_date(value)
      return nil if value.blank?

      Time.zone.parse(to_utf8(value))
    rescue ArgumentError, RangeError
      nil
    end

    def attachments_in(part)
      return [] if part.nil?
      return part.parts.flat_map { |child| attachments_in(child) } if part.multipart?

      filename = filename_of(part)
      return [] unless attachment?(part, filename)

      [ { "filename" => filename, "content_type" => "#{part.media_type}/#{part.subtype}".downcase, "size" => decoded_size(part) } ]
    end

    def attachment?(part, filename)
      disposition = part.disposition&.dsp_type.to_s.upcase.presence
      disposition == "ATTACHMENT" || (filename.present? && disposition != "INLINE")
    end

    def filename_of(part)
      # Content-Disposition parameters win over Content-Type ones.
      params = [ part.param, part.disposition&.param ].compact.reduce({}) do |merged, hash|
        merged.merge(hash.transform_keys { |key| key.to_s.upcase })
      end

      if (extended = params["FILENAME*"] || params["NAME*"])
        rfc2231_decode(extended)
      else
        decode(params["FILENAME"] || params["NAME"]).presence
      end
    end

    # RFC 2231: charset'language'percent-encoded-value
    def rfc2231_decode(value)
      charset, _language, encoded = to_utf8(value).split("'", 3)
      return decode(value) if encoded.nil?

      bytes = CGI.unescape(encoded.gsub("+", "%2B"))
      bytes.force_encoding(charset.presence || Encoding::UTF_8).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    rescue ArgumentError
      to_utf8(encoded).presence
    end

    # BODYSTRUCTURE reports the transfer-encoded size; base64 inflates content by 4/3.
    def decoded_size(part)
      size = part.size.to_i
      part.encoding.to_s.casecmp?("BASE64") ? size * 3 / 4 : size
    end
  end
end
