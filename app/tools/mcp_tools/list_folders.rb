# frozen_string_literal: true

module McpTools
  class ListFolders < ApplicationTool
    tool_name "list_folders"
    title "List folders"

    description <<~TEXT.squish
      List the folders of one mailbox with their message and unread counts. "path" is what
      the other tools take; "name" is the readable form. "special_use" says which folder is
      Sent, Trash, Drafts, Junk or Archive whatever language the server names it in.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" }
      },
      required: [ "account_id" ],
      additionalProperties: false
    )

    private
      def call
        folders = Imap::Connection.open(mail_account) do |imap|
          Imap::FolderLister.new(mail_account).list(imap).map { |folder| describe(imap, folder) }
        end
        rows_returned!(folders.size)
        json_result(folders: folders)
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end

      def describe(imap, folder)
        counts = folder.selectable ? imap.status(folder.name, %w[MESSAGES UNSEEN]) : {}
        {
          name: Net::IMAP.decode_utf7(folder.name),
          path: folder.name,
          delimiter: folder.delimiter,
          message_count: counts["MESSAGES"],
          unseen_count: counts["UNSEEN"],
          special_use: folder.special_use&.to_s
        }
      end
  end
end
