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
  #
  # Gmail (X-GM-EXT-1) needs one exception, or every message would be indexed two or three
  # times: labels are folders, "[Gmail]/All Mail" holds every message again, and Important and
  # Starred are views of messages that live elsewhere. The virtual views are not synced at all.
  # All Mail is synced last and keeps only the messages no other folder has indexed - matched by
  # X-GM-MSGID, the id Gmail gives every copy of one message - so archived mail, which sits in
  # All Mail alone, stays searchable. When an archived message gets a label again, the labelled
  # copy replaces its All Mail row. A message under several labels (INBOX and Work) keeps one row
  # per label, so searching a folder still finds it. Skipping All Mail outright would lose
  # archived mail; collapsing every label into one row would break folder search.
  # Servers without X-GM-EXT-1 (e.g. Dovecot's virtual \All) are synced folder by folder as before.
  class MessageSync
    BATCH_SIZE = 200

    # Gmail views whose messages are always in another synced folder too.
    GMAIL_VIRTUAL = %i[important flagged].freeze

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
        @gmail = imap.capability.include?("X-GM-EXT-1")
        folders_to_sync(FolderLister.new(mail_account).list(imap)).each do |remote_folder|
          sync_folder(imap, remote_folder)
        end
      end
      result
    end

    private

    attr_reader :mail_account, :batch_size, :timeout, :result, :gmail

    def folders_to_sync(remote_folders)
      selectable = remote_folders.select(&:selectable)
      return selectable unless gmail

      all_mail, labels = selectable.reject { |folder| GMAIL_VIRTUAL.include?(folder.special_use) }
                                   .partition { |folder| folder.special_use == :all }
      labels + all_mail
    end

    def sync_folder(imap, remote_folder)
      folder = mail_account.mail_folders.find_or_create_by!(name: remote_folder.name)
      folder.update!(delimiter: remote_folder.delimiter, special_use: remote_folder.special_use&.to_s)

      imap.examine(folder.name)
      check_uidvalidity(folder, imap.responses("UIDVALIDITY", &:last))
      import_new_messages(imap, folder, imap.responses("UIDNEXT", &:last))

      folder.update!(last_synced_at: Time.current, last_error: nil)
      result.folders_synced += 1
    rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError, MissingUidvalidity => e
      # A usage limit refuses every folder alike, so it ends the whole sync.
      raise if ServiceLimited.limit?(e)

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
        rows = Array(imap.uid_fetch(batch, fetch_attrs)).filter_map { |data| row_for(folder, data) }
        store_batch(folder, rows, batch.last)
      end
    end

    def fetch_attrs
      gmail ? MessageHeaders::FETCH_ATTRS + [ "X-GM-MSGID" ] : MessageHeaders::FETCH_ATTRS
    end

    def row_for(folder, fetch_data)
      return nil if fetch_data.uid.nil?

      MessageHeaders.attributes(fetch_data).merge(
        mail_account_id: mail_account.id,
        mail_folder_id: folder.id,
        uidvalidity: folder.uidvalidity,
        gm_msgid: gmail ? fetch_data.attr["X-GM-MSGID"] : nil
      )
    end

    # Rows and cursor are committed together, so the cursor never runs ahead of the index.
    def store_batch(folder, rows, last_uid)
      MailFolder.transaction do
        rows = dedupe_gmail(folder, rows) if gmail
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

    # All Mail keeps only what no other folder holds; any other folder takes over the All Mail
    # row of a message it now holds. See the class comment.
    def dedupe_gmail(folder, rows)
      gm_msgids = rows.filter_map { |row| row[:gm_msgid] }
      return rows if gm_msgids.empty?

      if folder.special_use == "all"
        indexed = mail_account.mail_messages.where(gm_msgid: gm_msgids).where.not(mail_folder_id: folder.id).distinct.pluck(:gm_msgid).to_set
        rows.reject { |row| indexed.include?(row[:gm_msgid]) }
      else
        all_mail = mail_account.mail_folders.where(special_use: "all").select(:id)
        mail_account.mail_messages.where(mail_folder_id: all_mail, gm_msgid: gm_msgids).delete_all
        rows
      end
    end
  end
end
