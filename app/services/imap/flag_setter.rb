module Imap
  # Sets or clears \Flagged and \Seen on one message on the server and mirrors the result in
  # the local index, so a search right afterwards sees it without waiting for the next sync.
  # The folder is opened with SELECT: a STORE is refused on an EXAMINEd mailbox.
  class FlagSetter
    FLAG_NAMES = { flagged: "Flagged", seen: "Seen" }.freeze

    class MessageGone < StandardError; end

    def self.call(message, **changes)
      new(message, **changes).call
    end

    def initialize(message, flagged: nil, seen: nil)
      @message = message
      @changes = { flagged:, seen: }.compact
    end

    def call
      Connection.open(message.mail_account) do |imap|
        select_folder(imap)
        changes.each { |key, on| imap.uid_store(message.uid, on ? "+FLAGS.SILENT" : "-FLAGS.SILENT", [ FLAG_NAMES.fetch(key).to_sym ]) }
      end
      message.update!(flags: updated_flags)
      message.flags
    end

    private
      attr_reader :message, :changes

      def select_folder(imap)
        imap.select(message.mail_folder.name)
        raise MessageGone unless imap.responses("UIDVALIDITY", &:last) == message.uidvalidity
        raise MessageGone if imap.uid_fetch(message.uid, "UID").blank?
      end

      def updated_flags
        changes.reduce(message.flags) do |flags, (key, on)|
          name = FLAG_NAMES.fetch(key)
          on ? (flags | [ name ]) : (flags - [ name ])
        end
      end
  end
end
