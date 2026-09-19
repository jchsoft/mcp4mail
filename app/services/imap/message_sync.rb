module Imap
  # Imports message headers from every folder of a MailAccount into mail_messages, so that
  # searching happens in Postgres and never through IMAP SEARCH at query time.
  #
  # Each folder is synced incrementally by UID: only messages above the folder's
  # last_synced_uid are fetched, in batches, and the cursor is committed together with each
  # batch. A crash mid-folder therefore resumes from the last committed batch instead of
  # starting over. The UIDVALIDITY reported on EXAMINE is checked on every run; when the
  # server has changed it, the stored UIDs no longer identify the same messages and the
  # folder is imported again from zero.
  class MessageSync
    BATCH_SIZE = 200

    # A first import of a large mailbox takes far longer than Connection's default timeout.
    # If it is hit anyway, the job is retried and continues from the committed cursors.
    TIMEOUT = 10.minutes.to_i

    # A server that does not report UIDVALIDITY gives no way to tell whether stored UIDs still
    # point at the same messages, so such a folder is not indexed at all.
    class MissingUidvalidity < StandardError; end

    Result = Struct.new(:folders_synced, :messages_imported, :folders_reset, :folders_failed, keyword_init: true)

    def self.call(mail_account, batch_size: BATCH_SIZE, timeout: TIMEOUT)
      new(mail_account, batch_size: batch_size, timeout: timeout).call
    end

    def initialize(mail_account, batch_size: BATCH_SIZE, timeout: TIMEOUT)
      @mail_account = mail_account
      @batch_size = batch_size
      @timeout = timeout
      @result = Result.new(folders_synced: 0, messages_imported: 0, folders_reset: [], folders_failed: [])
    end

    def call
      Connection.open(mail_account, timeout: timeout) do |imap|
        FolderLister.new(mail_account).list(imap).select(&:selectable).each do |remote_folder|
          sync_folder(imap, remote_folder)
        end
      end
      result
    end

    private

    attr_reader :mail_account, :batch_size, :timeout, :result

    def sync_folder(imap, remote_folder)
      folder = mail_account.mail_folders.find_or_create_by!(name: remote_folder.name)
      folder.update!(delimiter: remote_folder.delimiter, special_use: remote_folder.special_use&.to_s)

      imap.examine(folder.name)
      check_uidvalidity(folder, imap.responses("UIDVALIDITY", &:last))
      import_new_messages(imap, folder, imap.responses("UIDNEXT", &:last))

      folder.update!(last_synced_at: Time.current, last_error: nil)
      result.folders_synced += 1
    rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError, MissingUidvalidity => e
      # The folder is gone or cannot be opened; the other folders are still worth syncing.
      folder&.update_columns(last_error: e.message)
      result.folders_failed << remote_folder.name
    end

    def check_uidvalidity(folder, uidvalidity)
      raise MissingUidvalidity, "#{folder.name}: server reported no UIDVALIDITY" if uidvalidity.nil?
      return unless folder.adopt_uidvalidity!(uidvalidity)

      Rails.logger.warn(
        "[Imap::MessageSync] mail_account_id=#{mail_account.id} folder=#{folder.name.inspect} " \
        "UIDVALIDITY changed to #{uidvalidity}; re-importing the folder"
      )
      result.folders_reset << folder.name
    end

    def import_new_messages(imap, folder, uidnext)
      from_uid = folder.last_synced_uid + 1
      return if uidnext && from_uid >= uidnext

      # "n:*" also matches the highest UID when that is below n, hence the filter.
      uids = imap.uid_search([ "UID", Net::IMAP::SequenceSet.new(from_uid..) ]).select { |uid| uid >= from_uid }.sort

      uids.each_slice(batch_size) do |batch|
        rows = Array(imap.uid_fetch(batch, MessageHeaders::FETCH_ATTRS)).filter_map { |data| row_for(folder, data) }
        store_batch(folder, rows, batch.last)
      end
    end

    def row_for(folder, fetch_data)
      return nil if fetch_data.uid.nil?

      MessageHeaders.attributes(fetch_data).merge(
        mail_account_id: mail_account.id,
        mail_folder_id: folder.id,
        uidvalidity: folder.uidvalidity
      )
    end

    # Rows and cursor are committed together, so the cursor never runs ahead of the index.
    def store_batch(folder, rows, last_uid)
      MailFolder.transaction do
        if rows.any?
          MailMessage.upsert_all(
            rows,
            unique_by: %i[mail_folder_id uidvalidity uid],
            update_only: rows.first.keys - %i[mail_account_id mail_folder_id uidvalidity uid]
          )
        end
        folder.update!(last_synced_uid: last_uid)
      end
      result.messages_imported += rows.size
    end
  end
end
