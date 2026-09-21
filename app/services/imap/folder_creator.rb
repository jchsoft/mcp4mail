module Imap
  # Creates a folder and is idempotent about it: a folder that already exists is returned as
  # if it had just been made. Hosts that keep every folder under a namespace prefix (some
  # want "INBOX.") refuse the plain name, so the plain name is tried first, then the
  # prefix from NAMESPACE, then the error is raised.
  class FolderCreator
    Result = Struct.new(:path, :name, :delimiter, :created, keyword_init: true)

    def self.call(mail_account, name:, parent: nil)
      new(mail_account, name:, parent:).call
    end

    def initialize(mail_account, name:, parent: nil)
      @mail_account = mail_account
      @name = name
      @parent = parent
    end

    def call
      Connection.open(mail_account) { |imap| create(imap) }
    end

    private
      attr_reader :mail_account, :name, :parent

      def create(imap)
        folders = FolderLister.new(mail_account).list(imap)
        delimiter = folders.filter_map(&:delimiter).first || "/"
        wanted = encode(join(parent_path(folders), name, delimiter))

        existing = find(folders, wanted)
        return result(existing.name, existing.delimiter, false) if existing

        path = create_with_fallback(imap, wanted, folders, delimiter)
        result(path, delimiter, true)
      end

      # The parent is given the way the model saw it in list_folders: a path, or the readable name.
      def parent_path(folders)
        return nil if parent.blank?

        folders.find { |folder| folder.name == parent || Net::IMAP.decode_utf7(folder.name) == parent }&.name ||
          encode(parent)
      end

      def join(parent_path, leaf, delimiter)
        [ parent_path, leaf ].compact.join(delimiter)
      end

      def encode(value)
        value.ascii_only? ? value : Net::IMAP.encode_utf7(value)
      end

      def find(folders, path)
        folders.find { |folder| folder.name == path }
      end

      def create_with_fallback(imap, path, folders, delimiter)
        imap.create(path)
        path
      rescue Net::IMAP::NoResponseError => refusal
        return path if already_exists?(imap, path)

        prefix = namespace_prefix(imap)
        raise refusal if prefix.blank? || path.start_with?(prefix)

        prefixed = "#{prefix}#{path}"
        return prefixed if find(FolderLister.new(mail_account).list(imap), prefixed)

        imap.create(prefixed)
        prefixed
      end

      def already_exists?(imap, path)
        FolderLister.new(mail_account).list(imap).any? { |folder| folder.name == path }
      end

      def namespace_prefix(imap)
        return nil unless imap.capability.include?("NAMESPACE")

        imap.namespace&.personal&.first&.prefix
      end

      def result(path, delimiter, created)
        Result.new(path:, name: Net::IMAP.decode_utf7(path), delimiter:, created:)
      end
  end
end
