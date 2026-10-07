require "test_helper"

class Imap::MessageHeadersTest < ActiveSupport::TestCase
  Fetch = Struct.new(:uid, :envelope, :bodystructure, :internaldate, :rfc822_size, :flags, keyword_init: true)
  Part = Struct.new(:media_type, :subtype, :param, :disposition, :encoding, :size, keyword_init: true) do
    def multipart? = false
  end
  Multipart = Struct.new(:parts) do
    def multipart? = true
  end
  Disposition = Struct.new(:dsp_type, :param)

  INTERNAL_DATE = Time.utc(2026, 9, 17, 8, 0, 0)

  def address(name, mailbox, host)
    Net::IMAP::Address.new(name, nil, mailbox, host)
  end

  def envelope(date: "Thu, 17 Sep 2026 10:00:00 +0200", subject: "Hello", from: [ address("Ann", "Ann", "Example.COM") ], to: [], cc: [], message_id: " <id@example.com> ")
    Net::IMAP::Envelope.new(date, subject, from, from, from, to, cc, nil, nil, message_id)
  end

  def attributes(envelope: self.envelope, bodystructure: nil)
    fetch = Fetch.new(uid: 7, envelope:, bodystructure:, internaldate: INTERNAL_DATE, rfc822_size: 99, flags: [ :Seen ])
    Imap::MessageHeaders.attributes(fetch)
  end

  test "maps the envelope onto the row attributes" do
    result = attributes(envelope: envelope(to: [ address(nil, "bob", "example.net") ], cc: [ address("Cy", "cy", "example.net") ]))

    assert_equal 7, result[:uid]
    assert_equal "Ann", result[:from_name]
    assert_equal "ann@example.com", result[:from_address]
    assert_equal [ { "name" => nil, "address" => "bob@example.net" } ], result[:to_addresses]
    assert_equal [ { "name" => "Cy", "address" => "cy@example.net" } ], result[:cc_addresses]
    assert_equal "<id@example.com>", result[:message_id]
    assert_equal [ "Seen" ], result[:flags]
    assert_equal 99, result[:size]
    assert_not result[:has_attachments]
  end

  test "decodes an RFC 2047 encoded-word subject and name" do
    result = attributes(envelope: envelope(subject: "=?UTF-8?B?UMWZw61sacWhIMW+bHXFpW91xI1rw70=?=", from: [ address("=?UTF-8?Q?Jan_Nov=C3=A1k?=", "jan", "example.cz") ]))

    assert_equal "Příliš žluťoučký", result[:subject]
    assert_equal "Jan Novák", result[:from_name]
  end

  test "reads undeclared Windows-1250 bytes in a header" do
    result = attributes(envelope: envelope(subject: "Příliš".encode("Windows-1250").b))

    assert_equal "Příliš", result[:subject]
  end

  test "an encoded word with an unknown charset does not raise" do
    result = attributes(envelope: envelope(subject: "=?x-no-such-charset?Q?abc?="))

    assert_kind_of String, result[:subject]
  end

  test "an encoded word with a broken payload does not raise" do
    result = attributes(envelope: envelope(subject: "=?UTF-8?B?%%%not-base64?= tail"))

    assert_kind_of String, result[:subject]
  end

  test "a missing envelope leaves the headers empty and dates from the server" do
    result = attributes(envelope: nil)

    assert_nil result[:subject]
    assert_nil result[:from_address]
    assert_nil result[:message_id]
    assert_equal [], result[:to_addresses]
    assert_equal INTERNAL_DATE, result[:date]
  end

  test "an unparseable Date header falls back to the internal date" do
    result = attributes(envelope: envelope(date: "31-31-31 99:99"))

    assert_equal INTERNAL_DATE, result[:date]
  end

  test "group-syntax addresses without a host are skipped" do
    result = attributes(envelope: envelope(to: [ address(nil, "undisclosed-recipients", nil), address(nil, "bob", "example.net") ]))

    assert_equal [ "bob@example.net" ], result[:to_addresses].map { |a| a["address"] }
  end

  test "lists attachments from a multipart structure, sizing base64 by its decoded bytes" do
    text = Part.new(media_type: "TEXT", subtype: "PLAIN", param: { "CHARSET" => "UTF-8" }, encoding: "7BIT", size: 10)
    pdf = Part.new(media_type: "APPLICATION", subtype: "PDF", param: { "NAME" => "=?UTF-8?Q?zpr=C3=A1va.pdf?=" }, encoding: "BASE64", size: 400)
    inline = Part.new(media_type: "IMAGE", subtype: "PNG", param: { "NAME" => "logo.png" }, disposition: Disposition.new("INLINE", {}), encoding: "BASE64", size: 40)

    result = attributes(bodystructure: Multipart.new([ text, pdf, inline ]))

    assert result[:has_attachments]
    assert_equal [ { "filename" => "zpráva.pdf", "content_type" => "application/pdf", "size" => 300 } ], result[:attachments]
  end

  test "an RFC 2231 filename in the disposition wins over the content-type name" do
    part = Part.new(
      media_type: "APPLICATION", subtype: "OCTET-STREAM", param: { "NAME" => "plain.bin" },
      disposition: Disposition.new("ATTACHMENT", { "FILENAME*" => "UTF-8''p%C5%99%C3%ADloha.txt" }), encoding: "7BIT", size: 5
    )

    assert_equal "příloha.txt", attributes(bodystructure: part)[:attachments].first["filename"]
  end

  test "an RFC 2231 value with an unknown charset falls back to the raw text" do
    part = Part.new(
      media_type: "APPLICATION", subtype: "OCTET-STREAM", param: {},
      disposition: Disposition.new("ATTACHMENT", { "FILENAME*" => "no-such-charset'en'file.txt" }), encoding: "7BIT", size: 5
    )

    assert_equal "file.txt", attributes(bodystructure: part)[:attachments].first["filename"]
  end

  test "an RFC 2231 value without the charset prefix is decoded as an ordinary value" do
    part = Part.new(
      media_type: "APPLICATION", subtype: "OCTET-STREAM", param: {},
      disposition: Disposition.new("ATTACHMENT", { "FILENAME*" => "plain.txt" }), encoding: "7BIT", size: 5
    )

    assert_equal "plain.txt", attributes(bodystructure: part)[:attachments].first["filename"]
  end

  test "an attachment disposition without any filename is still listed" do
    part = Part.new(media_type: "APPLICATION", subtype: "ZIP", param: nil, disposition: Disposition.new("ATTACHMENT", nil), encoding: "7BIT", size: 5)

    assert_nil attributes(bodystructure: part)[:attachments].first["filename"]
  end
end
