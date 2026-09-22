# app/services

The IMAP boundary, plus the few services that sit next to it (`Smtp::*`, `MessageComposer`, `AttachmentDownloadToken`, `AccountExport`).

## Everything that talks to IMAP goes through `app/services/imap`

`Imap::Connection.open(mail_account) { |imap| ... }` is the only place `Net::IMAP.new` is called. No controller, job, model or tool opens a connection itself. It gives every caller, for free:

- STARTTLS when the account asks for it, then LOGIN;
- one timeout (`TIMEOUT`, 15 s) over the whole session, because net-imap's own `open_timeout` stops at the handshake and a server that goes quiet after LOGIN would hang a web worker;
- LOGOUT and disconnect in `ensure`, even on an exception;
- `last_connected_at` / `last_error` on a saved account, whichever service connected.

New IMAP work is a new file here that calls `Connection.open`, or an addition to an existing one. Not a second connection path.

## Autodetect: why there is no server form

The product refuses to make a person fill in host, port and TLS. `Imap::Autodetect.call(email:, password:)` works it out from the address, in this order:

1. `AutoconfigLookup`: Thunderbird's ISPDB, then the domain's own autoconfig XML. The provider's own answer, so it goes first.
2. `SrvLookup`: RFC 6186 `_imaps._tcp` / `_imap._tcp` records.
3. `GuessLookup`: common prefixes on the domain, the bare domain, and names mined from the MX record, on 993 (TLS) then 143 (STARTTLS).

Each source yields `Candidate`s, and `Prober` confirms them by actually logging in, in parallel but picking the first in preference order. A setting that does not authenticate is never offered. The whole run has a 15 s budget. A failed run returns a `reason` (`:no_server_found`, `:timeout`, `:auth_failed`, `:imap_disabled`), with a rejected login outranking "nothing found".

`Smtp::Autodetect` reuses the same sources for the outgoing server on the first send.

## The pieces

- `connection`: the one session opener, above.
- `connection_tester`: the manual-settings "test connection". Reports `:auth_failed`, `:tls_problem` and `:unreachable` separately, because people confuse them.
- `connection_problem`: turns an autodetect `reason` (and the server's raw response) into what the person should do, in their provider's words (`config/imap_providers.yml` + the `imap_problems` locale scope), plus the "Show me how" guide link.
- `folder_lister`: folders, with special-use roles from SPECIAL-USE or Gmail's XLIST.
- `message_sync`: imports headers into `mail_messages` so search runs in Postgres, never IMAP SEARCH. Incremental by UID, cursor committed per batch, folder re-imported when UIDVALIDITY changes.
- `message_headers`: one FETCH response into `MailMessage` attributes, all charsets (including undeclared Windows-1250) to UTF-8.
- `message_body`: one message's text, fetched live (bodies are never stored) with `BODY.PEEK[]` so reading never sets `\Seen`.
- `message_attachment`: one attachment's bytes, by the same depth-first index `message_headers` stored.
- Writes, each used only by a write tool: `draft_saver`, `folder_creator`, `flag_setter`, `message_mover`. Each mirrors its change into the local index so a search right after sees it.

## Failures are raised, not swallowed

A service does not turn a failure into `nil` or an empty list. Net::IMAP and socket errors propagate out of `Connection.open` (after it records `last_error`); a message that is no longer there raises the service's own `MessageGone`; `MessageMover` has `FolderNotFound` and `CannotMoveSafely`. The caller decides what the person or the model sees:

- the new-mailbox form shows the autodetect `reason` through `ConnectionProblem`, and the `ConnectionTester` outcome;
- a tool rescues into `Hitch::MCP::Result.error` with the next step spelled out;
- `MailAccountSyncJob` lets the error fail the job; connection errors (`Timeout::Error`, `ECONNRESET`, `IOError`, ...) are retried and resume from the committed cursors. `MessageSync` only records and skips a single folder the server refuses or that reports no UIDVALIDITY (`MailFolder#last_error`), because the other folders are still worth syncing.

## Tests fake the server, never `Net::IMAP`

- `test/support/fake_imap_server.rb`: a real-socket IMAP server on `127.0.0.1`. Describe folders and messages, point an account at its port. It records the commands it got. Failure modes (wrong password, TLS mismatch, a drop mid-fetch, refused STORE, a namespace prefix) are constructor options; see `test/CLAUDE.md`.
- `test/support/fake_autodetect_network.rb`: doubles for the HTTP, DNS and IMAP `Imap::Autodetect` talks to.

Do not mock or stub `Net::IMAP`, and never point a test at a real host. If the fake cannot produce what you need, extend the fake.
