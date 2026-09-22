module Imap
  # Builds a plain-text message and APPENDs it to the account's Drafts folder with \Draft, so
  # the person opens their own mail client and sends it. Drafts is found by SPECIAL-USE, then
  # by a name in the common languages, and created when the server has none. The saved message
  # is added to the local index when the server reports its UID (UIDPLUS); otherwise the next
  # sync imports it.
  class DraftSaver
    DRAFT_NAMES = %w[drafts entwürfe koncepty brouillons].freeze
    DEFAULT_FOLDER = "Drafts"
    MAX_BODY_BYTES = MessageComposer::MAX_BODY_BYTES
    MAX_RECIPIENTS = 50

    Result = Struct.new(:message, :folder, keyword_init: true)

    Invalid = MessageComposer::Invalid

    def self.call(mail_account, **fields)
      new(mail_account, **fields).call
    end

    def initialize(mail_account, to:, cc: [], bcc: [], subject: nil, body: nil, reply_to: nil)
      @mail_account = mail_account
      @composer = MessageComposer.new(mail_account, to:, cc:, bcc:, subject:, body:, reply_to:, max_recipients: MAX_RECIPIENTS)
    end

    def call
      composer.validate!
      mail = composer.mail
      Connection.open(mail_account) do |imap|
        path = drafts_path(imap)
        response = imap.append(path, mail.to_s, [ :Draft ], mail.date.to_time)
        Result.new(message: index(imap, path, mail, response), folder: Net::IMAP.decode_utf7(path))
      end
    end

    private
      attr_reader :mail_account, :composer

      delegate :to, :cc, :own_address, to: :composer

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
