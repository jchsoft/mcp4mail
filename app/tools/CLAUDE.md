# app/tools

The MCP tool contract: what a model connected to someone's mailbox is allowed to do, and what every call passes through on the way.

## Read-only is the default, a write is a product decision

A mailbox is read-only to the AI until its owner turns on "Allow the AI to make changes" (`MailAccount#writable`). A new tool that changes a mailbox is not an implementation detail of some feature: it needs an explicit decision first, and then it says so in code with `write_tool destructive: true|false`.

- `destructive: false`: the write only adds or is undoable (`create_draft`, `create_folder`, `move_message`, `set_flags`).
- `destructive: true`: something can be lost or leave the mailbox (`trash_message`, `send_message`).

`send_message` never sends. It stores an `OutgoingMessage` and emails the owner a link; only the owner's Send reaches SMTP. Keep it that way: no tool and no job delivers mail on its own.

## Registering a tool

`mcp_tool_registry.rb` is the list. A tool that is not registered there is neither listed nor callable. `McpToolRegistry.register` refuses to boot when the class:

- is not a subclass of `McpTools::ApplicationTool`,
- is neither read-only and non-destructive nor declared with `write_tool`,
- has no `title`.

Generate with `bin/rails generate hitch:tool NAME`, change the superclass to `ApplicationTool`, add one `register ... scopes: [ "mcp" ]` line (alphabetical).

## What `ApplicationTool` gives every tool

Inheriting is the whole integration. Do not reimplement any of this in a tool:

- Read-only annotations (`read_only_hint: true`, `destructive_hint: false`, ...) set on `inherited`; `write_tool` flips them.
- `authorize!`: an `account_id` argument that is not one of the caller's `MailAccount`s is refused, and recorded as `denied`, before any tool code runs.
- `invoke`, wrapped around your private `#call`:
  - a write tool against a mailbox that is not writable returns `READ_ONLY_MAILBOX` and never reaches `#call`;
  - `USER_CALLS` (an `McpQuota`, 240 calls a minute per user across all their clients);
  - `McpSearchGuard::Exhausted` turned into a tool error;
  - an `McpAuditEvent` in `ensure`, whatever the outcome, and an `McpClientSighting`.
- Helpers: `current_user`, `mail_accounts`, `mail_account`, `search_guard`, `rows_returned!(n)`, `json_result(value)`, `account_summary(account)`.

Every lookup goes through the caller: `mail_accounts` for accounts, `MailMessage.for_user(current_user)` for messages. Never `MailMessage.find`. A write tool whose mailbox comes from a message id (not an `account_id`) overrides `mail_account`, because the writable check asks it which mailbox is about to change.

## The guards, and what each one defends against

- `McpQuota`: a fixed-window counter in Hitch's shared rate-limit store. Hitch already limits each user + client pair; this is for limits Hitch does not know about. Build new limits on it instead of counting yourself. Tests set `McpQuota.store_override`.
- `McpSearchGuard`: a runaway agent loop walking a whole mailbox through search. It caps the page size (`MAX_PAGE_SIZE`) and budgets searches and returned rows per account (or per user for a search across all accounts). A tool that returns rows from the index calls `search_guard.admit!` before the query and `search_guard.record_rows(n)` after (`search_messages`, `search_contacts`).
- `McpAuditEvent`: after-the-fact review of what the AI did: tool, account, outcome, row count, duration. It never stores arguments or results, so the log cannot leak mail. Call `rows_returned!` so the row count is right.

## The tools

| Tool | Does | Kind |
| --- | --- | --- |
| `list_mail_accounts` | The caller's mailboxes, with the ids the other tools take | read |
| `get_mail_account` | One mailbox's settings | read |
| `list_folders` | A mailbox's folders, special-use ones marked | read |
| `search_messages` | Header rows from the local index, never bodies | read |
| `get_message` | One message's text, fetched live over IMAP | read |
| `search_contacts` | Addresses seen in the index | read |
| `get_attachment` | A signed download URL for one attachment, or with `inline: true` its base64 bytes | read |
| `get_outgoing_status` | Whether a prepared email was sent | read |
| `create_draft`, `create_folder`, `move_message`, `set_flags` | | write |
| `trash_message`, `send_message` | | write, destructive |

## Writing a good tool

The name, `title`, `description` and every `input_schema` description are read by a model, not a person. So:

- English, plain language, no internal jargon.
- Say what it returns and which tool gives the ids it needs ("the message id from search_messages").
- Say the limits in the description (row caps, size caps) and what to do when hit ("narrow the query rather than asking for a bigger limit").
- Error results are instructions: tell the model the next step ("Run search_messages again to get a fresh id"), not an error code. Rescue the IMAP failures (`Net::IMAP::Error`, `IOError`, `Timeout::Error`, `SocketError`, `SystemCallError`) and the service's own errors into `Hitch::MCP::Result.error`, as the existing tools do.
- `title` is what a person sees, in MCP clients and in the activity list ("Search messages").

Keep results small. `search_messages` returns headers only because one answer full of bodies would fill the model's context and leave it useless for the rest of the conversation.

## Attachments: a signed URL, or inline bytes

By default `get_attachment` never returns bytes. It reads the attachment metadata already in the index and returns a URL carrying an `AttachmentDownloadToken` (`app/services/attachment_download_token.rb`): signed, 5 minutes, bound to one user, one message and one attachment index. Visiting it re-fetches the attachment over IMAP.

With `inline: true` it fetches the attachment over IMAP itself and returns it as `content_base64`. That is for sandboxed agents whose network allowlist does not include this server, so a URL on it is unreachable; the bytes travel over the MCP connection that is already authenticated, and no bearer URL exists to leak. Same lookup as every read tool (`MailMessage.for_user`), and a lower cap (`MAX_INLINE_BYTES`, 5 MB) than the URL mode (10 MB), because the whole file lands in the model's context. Over the cap it refuses and tells the model to call again without `inline`. It is the only tool that puts file content in a result, and like every tool it is audited by metadata only.
