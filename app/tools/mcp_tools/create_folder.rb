# frozen_string_literal: true

module McpTools
  class CreateFolder < ApplicationTool
    tool_name "create_folder"
    title "Create folder"
    write_tool destructive: false
    annotations(**annotations, idempotent_hint: true)

    description <<~TEXT.squish
      Create a folder in a mailbox. Asking for a folder that already exists succeeds and
      returns it. Give "parent" (a path or name from list_folders) to create a subfolder.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: { type: "integer", description: "Id from list_mail_accounts" },
        name: { type: "string", description: "Name of the new folder" },
        parent: { type: "string", description: "Optional parent folder, from list_folders" }
      },
      required: [ "account_id", "name" ],
      additionalProperties: false
    )

    private
      def call
        return Hitch::MCP::Result.error("Give create_folder a name.") if arguments["name"].blank?

        folder = Imap::FolderCreator.call(mail_account, name: arguments["name"].strip, parent: arguments["parent"].presence)
        rows_returned!(1)
        json_result(path: folder.path, name: folder.name, delimiter: folder.delimiter, created: folder.created)
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
        Hitch::MCP::Result.error("The mail server refused to create the folder: #{e.message}")
      rescue Net::IMAP::Error, IOError, Timeout::Error, SocketError, SystemCallError => e
        Hitch::MCP::Result.error("Could not reach the mail server (#{e.message}). Try again.")
      end
  end
end
