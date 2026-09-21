module Imap
  # Moves one message to another folder on the server and mirrors the move in the local
  # index. The destination is a folder path, its readable name, or a special-use name
  # (Archive, Trash, ...). UID MOVE is used where the server has MOVE; otherwise the message
  # is copied, flagged \Deleted and removed with UID EXPUNGE, which touches nothing else.
  class MessageMover
    Result = Struct.new(:folder, :moved, keyword_init: true)

    class FolderNotFound < StandardError; end
    class MessageGone < StandardError; end
    class CannotMoveSafely < StandardError; end

    def self.call(message, to:)
      new(message, to:).call
    end

    def initialize(message, to:)
      @message = message
      @destination = to.to_s.strip
    end

    def call
      account = message.mail_account
      Connection.open(account) do |imap|
        target = resolve(FolderLister.new(account).list(imap))
        source = message.mail_folder
        return Result.new(folder: target.name, moved: false) if target.name == source.name

        select_source(imap)
        assigned = transfer(imap, target.name)
        reindex(target, assigned)
        Result.new(folder: target.name, moved: true)
      end
    end

    private
      attr_reader :message, :destination

      def resolve(folders)
        selectable = folders.select(&:selectable)
        found = selectable.find { |folder| folder.name == destination } ||
          selectable.find { |folder| folder.special_use.to_s.casecmp?(destination) } ||
          selectable.find { |folder| Net::IMAP.decode_utf7(folder.name).casecmp?(destination) }
        found || raise(FolderNotFound, "No folder called #{destination.inspect}. Call list_folders for the folders of this mailbox.")
      end

      def select_source(imap)
        imap.select(message.mail_folder.name)
        raise MessageGone unless imap.responses("UIDVALIDITY", &:last) == message.uidvalidity
        raise MessageGone if imap.uid_fetch(message.uid, "UID").blank?
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError
        raise MessageGone
      end

      # Returns the UID the message got in the destination, or nil when the server does not say.
      def transfer(imap, target_name)
        capabilities = imap.capability
        if capabilities.include?("MOVE")
          response = imap.uid_move(message.uid, target_name)
        else
          raise CannotMoveSafely, "This server can neither MOVE nor UID EXPUNGE, so a message cannot be moved without risking others." unless capabilities.include?("UIDPLUS")

          response = imap.uid_copy(message.uid, target_name)
          imap.uid_store(message.uid, "+FLAGS.SILENT", [ :Deleted ])
          imap.uid_expunge(message.uid)
        end
        copy_uid(imap, response)
      end

      def copy_uid(imap, response)
        data = imap.responses("COPYUID", &:last) || response&.data&.code&.data
        return nil unless data.respond_to?(:assigned_uids)

        [ data.uidvalidity, data.assigned_uids.numbers.first ]
      end

      # With the new UID the row follows the message; without it the row is dropped and the
      # next sync of the destination imports the message again.
      def reindex(target, assigned)
        folder = message.mail_account.mail_folders.find_by(name: target.name)
        if assigned && folder && folder.uidvalidity == assigned.first
          message.update!(mail_folder: folder, uid: assigned.last, uidvalidity: folder.uidvalidity)
        else
          message.destroy!
        end
      end
  end
end
