module Imap
  # Builds a plain-text message and APPENDs it to the account's Drafts folder with \Draft, so
  # the person opens their own mail client and sends it. Drafts is found by SPECIAL-USE, then
  # by a name in the common languages, and created when the server has none. The saved message
  # is added to the local index when the server reports its UID (UIDPLUS); otherwise the next
  # sync imports it.
  class DraftSaver
    DRAFT_NAMES = %w[drafts entwürfe koncepty brouillons].freeze
    DEFAULT_FOLDER = "Drafts"
    MAX_BODY_BYTES = 100 * 1024
    MAX_RECIPIENTS = 50

    Result = Struct.new(:message, :folder, keyword_init: true)

    class Invalid < StandardError; end

    def self.call(mail_account, **fields)
      new(mail_account, **fields).call
    end

    def initialize(mail_account, to:, cc: [], bcc: [], subject: nil, body: nil, reply_to: nil)
      @mail_account = mail_account
      @to = Array(to)
      @cc = Array(cc)
      @bcc = Array(bcc)
      @subject = subject.to_s.gsub(/[\r\n]+/, " ").strip
      @body = body.to_s
      @reply_to = reply_to
    end

    def call
      validate!
      mail = build_mail
      Connection.open(mail_account) do |imap|
        path = drafts_path(imap)
        response = imap.append(path, mail.to_s, [ :Draft ], mail.date.to_time)
        Result.new(message: index(imap, path, mail, response), folder: Net::IMAP.decode_utf7(path))
      end
    end

    private
      attr_reader :mail_account, :to, :cc, :bcc, :subject, :body, :reply_to

      def validate!
        recipients = to + cc + bcc
        raise Invalid, "Give at least one recipient in \"to\"." if to.empty?
        raise Invalid, "A draft can have at most #{MAX_RECIPIENTS} recipients in total." if recipients.size > MAX_RECIPIENTS
        raise Invalid, "The body can be at most #{MAX_BODY_BYTES / 1024} kB." if body.bytesize > MAX_BODY_BYTES

        bad = recipients.find { |address| !valid_address?(address) }
        raise Invalid, "#{bad.to_s.inspect} is not an email address." if bad
      end

      def valid_address?(address)
        parsed = Mail::Address.new(address.to_s)
        parsed.address.to_s.match?(/\A[^\s@<>,;]+@[^\s@<>,;]+\z/)
      rescue Mail::Field::ParseError
        false
      end

      def build_mail
        original = reply_to
        sender = own_address
        text = body
        subj = reply_subject(original)
        message_id = "#{SecureRandom.uuid}@#{message_id_domain(sender)}"
        threading = original&.message_id.presence

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
          mail.to = to
          mail.cc = cc if cc.any?
          mail.bcc = bcc if bcc.any?
        end
      end

      def reply_subject(original)
        return subject if original.nil?

        base = subject.presence || original.subject.to_s
        base.match?(/\Are:/i) ? base : "Re: #{base}".strip
      end

      def own_address
        username = mail_account.username
        username.include?("@") ? username : "#{username}@#{mail_account.host}"
      end

      def message_id_domain(sender)
        sender.split("@").last
      end

      def drafts_path(imap)
        folders = FolderLister.new(mail_account).list(imap).select(&:selectable)
        found = folders.find { |folder| folder.special_use == :drafts } ||
          folders.find { |folder| DRAFT_NAMES.include?(Net::IMAP.decode_utf7(folder.name).downcase) }
        found ? found.name : FolderCreator.new(mail_account, name: DEFAULT_FOLDER).create_in(imap).path
      end

      def index(imap, path, mail, response)
        data = response&.data&.code&.data
        return nil unless data.respond_to?(:assigned_uids)

        folder = mail_account.mail_folders.find_or_create_by!(name: path)
        folder.adopt_uidvalidity!(data.uidvalidity)
        from = { "name" => nil, "address" => own_address.downcase }
        to_list = to.map { |address| { "name" => nil, "address" => Mail::Address.new(address).address.downcase } }
        cc_list = cc.map { |address| { "name" => nil, "address" => Mail::Address.new(address).address.downcase } }

        MailMessage.create!(
          mail_account:, mail_folder: folder, uidvalidity: data.uidvalidity, uid: data.assigned_uids.numbers.first,
          date: mail.date.to_time, internal_date: mail.date.to_time, from_address: from["address"],
          to_addresses: to_list, cc_addresses: cc_list, subject: mail.subject, message_id: "<#{mail.message_id}>",
          in_reply_to: mail.in_reply_to && "<#{mail.in_reply_to}>", flags: [ "Draft" ], size: mail.to_s.bytesize,
          search_text: MailMessage.build_search_text(
            subject: mail.subject, from_name: nil, from_address: from["address"], to_addresses: to_list, cc_addresses: cc_list
          )
        )
      end
  end
end
