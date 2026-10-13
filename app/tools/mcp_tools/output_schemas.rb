# frozen_string_literal: true

module McpTools
  # The JSON Schema of what every tool returns on success, kept in one place. Each tool names its
  # own with `output_schema OutputSchemas::X`. Hitch validates every result against it, so a
  # field added to a tool's response has to be added here too.
  module OutputSchemas
    def self.object(properties, required: properties.keys)
      { type: "object", properties:, required:, additionalProperties: false }
    end

    def self.nullable(type, description)
      { type: [ type, "null" ], description: }
    end

    ATTACHMENT_SUMMARY = object(
      {
        filename: nullable("string", "File name, null when the sender gave none"),
        content_type: { type: "string", description: "MIME type, e.g. application/pdf" },
        size: { type: "integer", description: "Decoded size in bytes" }
      }
    )

    ACCOUNT = object(
      {
        id: { type: "integer", description: "Account id to pass to the other tools" },
        display_name: nullable("string", "Name the owner gave this mailbox"),
        host: { type: "string", description: "IMAP host" },
        port: { type: "integer", description: "IMAP port" },
        ssl: { type: "boolean", description: "Whether the connection is IMAPS" },
        username: { type: "string", description: "IMAP username" },
        default_folder: nullable("string", "Folder searched by default"),
        writable: { type: "boolean", description: "Whether the owner allows the AI to make changes" },
        ai_permissions: {
          type: "array",
          items: { type: "string", enum: %w[flags organize drafts send trash] },
          description: "Groups of changes the AI may make in this mailbox"
        },
        indexed_at: nullable("string", "ISO 8601 time the mail index was last refreshed (oldest folder sync)"),
        sync_errors: {
          type: "array",
          description: "Folders that failed to sync; present only when there are any",
          items: object(
            {
              folder: { type: "string", description: "Folder name" },
              error: { type: "string", description: "Last sync error" }
            }
          )
        }
      },
      required: %w[id display_name host port ssl username default_folder writable ai_permissions indexed_at]
    )

    LIST_MAIL_ACCOUNTS = object(
      { accounts: { type: "array", items: ACCOUNT, description: "Connected mail accounts" } }
    )

    GET_MAIL_ACCOUNT = ACCOUNT

    LIST_FOLDERS = object(
      {
        folders: {
          type: "array",
          description: "Folders of the mailbox",
          items: object(
            {
              name: { type: "string", description: "Readable folder name" },
              path: { type: "string", description: "Folder path as the server names it; pass this to tools taking a folder" },
              delimiter: nullable("string", "Hierarchy delimiter"),
              message_count: nullable("integer", "Messages in the folder, null for folders that cannot be selected"),
              unseen_count: nullable("integer", "Unread messages, null for folders that cannot be selected"),
              special_use: nullable("string", "Role of the folder, e.g. sent, trash, drafts")
            }
          )
        }
      }
    )

    SEARCH_MESSAGES = object(
      {
        messages: {
          type: "array",
          description: "Matching messages, newest first",
          items: object(
            {
              id: { type: "integer", description: "Message id for get_message" },
              account_id: { type: "integer", description: "Account the message is in" },
              folder: { type: "string", description: "Folder name" },
              date: nullable("string", "ISO 8601 date of the message"),
              from: nullable("string", "Sender, name and address"),
              subject: nullable("string", "Subject line"),
              unread: { type: "boolean", description: "True when the message has no Seen flag" },
              has_attachments: { type: "boolean", description: "Whether the message has attachments" },
              attachments: {
                type: "array",
                description: "Attachment file names and sizes; present only when the message has attachments",
                items: object(
                  {
                    filename: nullable("string", "File name"),
                    size: { type: "integer", description: "Size in bytes" }
                  }
                )
              }
            },
            required: %w[id account_id folder date from subject unread has_attachments]
          )
        },
        returned: { type: "integer", description: "Number of messages returned" },
        truncated: { type: "boolean", description: "True when more messages match than were returned" },
        note: { type: "string", description: "How to narrow the search; present only when truncated" }
      },
      required: %w[messages returned truncated]
    )

    GET_MESSAGE = object(
      {
        id: { type: "integer", description: "Message id" },
        account_id: { type: "integer", description: "Account the message is in" },
        folder: { type: "string", description: "Folder name" },
        date: nullable("string", "ISO 8601 date of the message"),
        from: nullable("string", "Sender, name and address"),
        to: { type: "array", items: { type: "string" }, description: "Recipients" },
        cc: { type: "array", items: { type: "string" }, description: "Carbon-copy recipients" },
        subject: nullable("string", "Subject line"),
        body: nullable("string", "Plain-text body"),
        truncated: { type: "boolean", description: "True when the body was cut off" },
        attachments: {
          type: "array",
          description: "Attachments; the position is the attachment_index for get_attachment",
          items: ATTACHMENT_SUMMARY
        },
        note: { type: "string", description: "Present only when the body was cut off" }
      },
      required: %w[id account_id folder date from to cc subject body truncated attachments]
    )

    GET_ATTACHMENT = object(
      {
        message_id: { type: "integer", description: "Message the attachment belongs to" },
        attachment_index: { type: "integer", description: "Position in the message's attachments" },
        filename: nullable("string", "File name"),
        content_type: { type: "string", description: "MIME type" },
        size: { type: "integer", description: "Size in bytes" },
        url: { type: "string", description: "Short-lived download link; present unless inline was requested" },
        expires_in_seconds: { type: "integer", description: "Seconds the download link stays valid" },
        content_base64: { type: "string", description: "Base64 file content; present only with inline" }
      },
      required: %w[message_id attachment_index filename content_type size]
    )

    CREATE_DRAFT = object(
      {
        message_id: nullable("integer", "Id of the saved draft once it is indexed, otherwise null"),
        folder: { type: "string", description: "Drafts folder the draft was saved to" },
        message: { type: "string", description: "What happened and what to do next" }
      }
    )

    SEND_MESSAGE = object(
      {
        outgoing_message_id: { type: "integer", description: "Id for get_outgoing_status" },
        state: { type: "string", enum: %w[pending sent discarded expired], description: "Where the message is now" },
        expires_at: { type: "string", description: "ISO 8601 time the owner's approval window ends" },
        message: { type: "string", description: "Tells you the owner has to approve before it is sent" }
      }
    )

    GET_OUTGOING_STATUS = object(
      {
        outgoing_message_id: { type: "integer", description: "Id of the outgoing message" },
        account_id: { type: "integer", description: "Account it is sent from" },
        state: { type: "string", enum: %w[pending sent discarded expired], description: "Where the message is now" },
        sent_at: nullable("string", "ISO 8601 time it was sent, null until then"),
        expires_at: { type: "string", description: "ISO 8601 time the owner's approval window ends" }
      }
    )

    MOVE_MESSAGE = object(
      {
        moved: { type: "boolean", description: "Whether the message was moved" },
        folder: { type: "string", description: "Readable name of the destination folder" },
        path: { type: "string", description: "Path of the destination folder" }
      }
    )

    SET_FLAGS = object(
      {
        id: { type: "integer", description: "Message id" },
        flags: { type: "array", items: { type: "string" }, description: "All IMAP flags now on the message" },
        flagged: { type: "boolean", description: "Whether the message is flagged" },
        seen: { type: "boolean", description: "Whether the message is marked read" }
      }
    )

    TRASH_MESSAGE = object(
      {
        trashed: { type: "boolean", description: "Whether the message was moved to Trash" },
        folder: { type: "string", description: "Readable name of the Trash folder" },
        path: { type: "string", description: "Path of the Trash folder" }
      }
    )

    CREATE_FOLDER = object(
      {
        path: { type: "string", description: "Path of the folder" },
        name: { type: "string", description: "Folder name" },
        delimiter: nullable("string", "Hierarchy delimiter"),
        created: { type: "boolean", description: "False when the folder already existed" }
      }
    )

    SEARCH_CONTACTS = object(
      {
        contacts: {
          type: "array",
          description: "People matching the query, most frequent first",
          items: object(
            {
              name: nullable("string", "Most common display name, null when none was seen"),
              address: { type: "string", description: "Email address" },
              messages_count: { type: "integer", description: "Messages exchanged with this address" },
              last_seen_at: nullable("string", "ISO 8601 date of the latest message"),
              direction: { type: "string", enum: %w[from to both], description: "Whether they wrote to you, you wrote to them, or both" }
            }
          )
        }
      }
    )
  end
end
