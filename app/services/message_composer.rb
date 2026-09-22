# Turns what the model asked for (recipients, subject, plain-text body, the message it answers)
# into a checked RFC 5322 message. Saving a draft and sending one build it the same way, so a
# sent message looks exactly like the draft it would have been.
class MessageComposer
  MAX_BODY_BYTES = 100 * 1024

  class Invalid < StandardError; end

  attr_reader :to, :cc, :bcc, :body

  # reply_to is an indexed MailMessage; in_reply_to is its Message-ID when only that is kept
  # (an OutgoingMessage waiting for approval).
  def initialize(mail_account, to:, cc: [], bcc: [], subject: nil, body: nil, reply_to: nil, in_reply_to: nil, max_recipients: 50)
    @mail_account = mail_account
    @to = Array(to)
    @cc = Array(cc)
    @bcc = Array(bcc)
    @subject = subject.to_s.gsub(/[\r\n]+/, " ").strip
    @body = body.to_s
    @reply_to = reply_to
    @in_reply_to = in_reply_to.presence || reply_to&.message_id.presence
    @max_recipients = max_recipients
  end

  def recipients
    to + cc + bcc
  end

  def validate!
    raise Invalid, "Give at least one recipient in \"to\"." if to.empty?
    raise Invalid, "A message can have at most #{max_recipients} recipients in total." if recipients.size > max_recipients
    raise Invalid, "The body can be at most #{MAX_BODY_BYTES / 1024} kB." if body.bytesize > MAX_BODY_BYTES

    bad = recipients.find { |address| !valid_address?(address) }
    raise Invalid, "#{bad.to_s.inspect} is not an email address." if bad

    self
  end

  # A reply gets "Re:" and falls back to the original's subject when the model gave none.
  def subject
    return @subject if reply_to.nil?

    base = @subject.presence || reply_to.subject.to_s
    base.match?(/\Are:/i) ? base : "Re: #{base}".strip
  end

  def in_reply_to
    @in_reply_to
  end

  def own_address
    mail_account.sender_address
  end

  def mail
    sender = own_address
    text = body
    subj = subject
    message_id = "#{SecureRandom.uuid}@#{sender.split('@').last}"
    threading = in_reply_to
    to_list, cc_list, bcc_list = to, cc, bcc

    Mail.new do
      from sender
      date Time.current
      message_id message_id
      self.subject = subj
      self.charset = "UTF-8"
      body text
      in_reply_to threading if threading
      references threading if threading
    end.tap do |mail|
      mail.to = to_list
      mail.cc = cc_list if cc_list.any?
      mail.bcc = bcc_list if bcc_list.any?
    end
  end

  private
    attr_reader :mail_account, :reply_to, :max_recipients

    def valid_address?(address)
      parsed = Mail::Address.new(address.to_s)
      parsed.address.to_s.match?(/\A[^\s@<>,;]+@[^\s@<>,;]+\z/)
    rescue Mail::Field::ParseError
      false
    end
end
