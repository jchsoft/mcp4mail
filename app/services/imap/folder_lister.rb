module Imap
  # Lists the folders on a MailAccount, identifying the special-use ones (Sent, Archive,
  # Trash, ...) where the server advertises them. Servers vary a lot in what they support:
  # RFC 6154 SPECIAL-USE, the older Gmail XLIST extension, or neither - so this detects
  # capabilities instead of assuming one.
  class FolderLister
    Folder = Struct.new(:name, :delimiter, :special_use, keyword_init: true)

    # RFC 6154 SPECIAL-USE attributes, and the older Gmail XLIST attributes they replaced,
    # normalized to a shared vocabulary.
    SPECIAL_USE = {
      "Sent" => :sent, "Trash" => :trash, "Archive" => :archive, "Junk" => :junk,
      "Drafts" => :drafts, "All" => :all, "Flagged" => :flagged,
      # net-imap capitalizes parsed flags (String#capitalize), so the Gmail XLIST
      # attribute "\AllMail" comes through as :Allmail, not :AllMail.
      "Allmail" => :all, "Spam" => :junk, "Starred" => :flagged
    }.freeze

    def self.call(mail_account)
      new(mail_account).call
    end

    def initialize(mail_account)
      @mail_account = mail_account
    end

    def call
      Connection.open(mail_account) { |imap| list(imap) }
    end

    private

    attr_reader :mail_account

    def list(imap)
      mailboxes = use_xlist?(imap.capability) ? imap.xlist("", "*") : imap.list("", "*")
      mailboxes.map { |mailbox| build_folder(mailbox) }
    end

    def use_xlist?(capabilities)
      capabilities.include?("XLIST") && !capabilities.include?("SPECIAL-USE")
    end

    def build_folder(mailbox)
      Folder.new(name: mailbox.name, delimiter: mailbox.delim, special_use: special_use_for(mailbox))
    end

    def special_use_for(mailbox)
      return :inbox if mailbox.name.casecmp?("INBOX")

      attr = mailbox.attr.map(&:to_s).find { |a| SPECIAL_USE.key?(a) }
      SPECIAL_USE[attr]
    end
  end
end
