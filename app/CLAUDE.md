# app

How this app is layered, and where a new thing goes. Not a directory listing — the rule, the reason, the trap.

## Controllers stay thin

`ApplicationController` includes two concerns that carry the cross-cutting behaviour; a controller action should not need to reimplement either.

- `concerns/authentication.rb`: `before_action :require_authentication` on every controller (opt out per-controller with `allow_unauthenticated_access`). `resume_session` looks up `Session.find_by(id: cookies.signed[:session_id])` and memoizes it into `Current.session`. An unauthenticated request is redirected to sign-in with `session[:return_to_after_authenticating] = request.url`; `after_authentication_url` pops that key after sign-in (falling back to `root_url`) so the user lands back where they started. `start_new_session_for(user)` and `terminate_session` are the only places a `Session` row is created or destroyed.
- `concerns/localization.rb`: `around_action :switch_locale` wraps every action in `I18n.with_locale`. Resolution order: `?locale=` param (persisted into `session[:locale]`) → stored `session[:locale]` → best match from `Accept-Language` → `I18n.default_locale`. Only `cs`/`en` are ever accepted; nothing else reaches `I18n.locale`.

A controller that needs the current user reads `Current.user`, not the session cookie directly.

## Models

- `Current`: request-scoped `session` (and the `user` it delegates to). Read this instead of threading the session through method calls.
- `Session`, `User`: a session belongs to a user; `User` has `has_secure_password` and owns `mail_accounts`, `mcp_audit_events`, `mcp_client_sightings`, `account_export_files`.
- The mail trio: `MailAccount` is one IMAP mailbox's credentials (encrypted password) and TLS settings; `MailFolder` tracks a folder's sync cursor and calls `adopt_uidvalidity!` to wipe and re-sync when the server's UIDVALIDITY changes underneath it; `MailMessage` is the locally indexed header cache (no bodies — those are fetched live over IMAP) with a diacritic- and case-insensitive `search` scope.
- `MailProvider`: the static `PRESETS` list behind the new-mailbox form. Adding a host here is the entire feature; it is not a settings screen and must not become one.
- The MCP guardrails, each protecting against a different failure mode:
  - `McpQuota`: a generic fixed-window rate counter (backed by Hitch's shared store). Other guards build on it rather than counting requests themselves.
  - `McpSearchGuard`: stops one client from turning search into a full-mailbox scrape — caps page size (`MAX_PAGE_SIZE`) and enforces per-subject `McpQuota`s on both search calls and rows returned.
  - `McpAuditEvent`: one row per MCP tool call (tool, account, outcome, row count, duration) for after-the-fact review. Deliberately never stores call arguments, so a logged event can't leak mail content.
  - `McpClientSighting`: tracks which OAuth client has touched which mailbox from which IP, and emails the mailbox owner on a first sighting — the detection half of "the AI can read your mail," where the audit event is the record of it.

## `app/services/imap`

Every IMAP session opens through `Imap::Connection.open(mail_account) { |imap| ... }`. No controller, job, or other service calls `Net::IMAP.new` directly — if new code needs the mailbox, it goes through this method or through one of the existing services (`message_sync.rb`, `message_body.rb`, `folder_lister.rb`, `draft_saver.rb`, and the rest of the files beside it) rather than opening a second connection path.

`Imap::Autodetect.call(email:, password:)` is what the new-mailbox form uses to fill in the host/port before the user has to. It tries, in order: autoconfig (Thunderbird ISPDB and the domain's own autoconfig XML) → DNS SRV records → heuristic hostname guesses. Every candidate any of those three produce is verified by a real login attempt before it's offered back — a plausible-looking guess that doesn't authenticate is never surfaced.

## `app/tools`

`McpToolRegistry` is the registry: `self.register` refuses to boot with a tool that is not a `McpTools::ApplicationTool`, or one that declares neither read-only nor a write. `McpTools::ApplicationTool` is where that declaration lives — every subclass defaults to read-only; `write_tool destructive: true|false` is the only way to opt a tool into writing, and it is what flips the MCP `read_only_hint`/`destructive_hint` annotations the client sees. The base class also enforces, on every `invoke`, that a write tool only runs against a mailbox with "Allow the AI to make changes" on, applies the per-user call quota, and always records a `McpAuditEvent` — a new tool under `mcp_tools/` gets all three for free by inheriting from it and does not reimplement any of them.

## Jobs

- `MailAccountSyncJob` syncs one `MailAccount` via `Imap::MessageSync.call`. `limits_concurrency to: 1` per account, so two syncs for the same mailbox never race; it's enqueued directly after a mailbox is added or its credentials change (`MailAccountsController`).
- `MailIndexRefreshJob` fans out `MailAccountSyncJob.perform_later` for every `MailAccount`. It's the one on a schedule — `config/recurring.yml` runs it every 15 minutes in production.
- Safe to assume: each account's sync is self-contained and resumable from its own `MailFolder` cursor, so nothing depends on jobs running in a particular order relative to each other, only on a single account's own syncs not overlapping.

## Views

Two layouts, `layouts/public.html.erb` (marketing + hitch-rails screens) and `layouts/application.html.erb` (signed in) — which controller uses which, the shared partial vocabulary, and the DOM ids the test suite holds onto are in `app/views/CLAUDE.md`. Anything visual (tokens, type scale, copy rules) is `docs/design/GUIDELINES.md`; check both before adding markup here.

## Stimulus (`app/javascript/controllers`)

Small, single-purpose controllers — no framework creep, no state shared between them:

- `clipboard_controller.js`: copies a target element's text to the clipboard, flashes a "copied" confirmation on the button.
- `auto_submit_controller.js`: calls `requestSubmit()` on its form as soon as a watched control changes, for settings that save themselves without an explicit button.
- `tabs_controller.js`: progressively enhances a stack of always-visible panels into an accessible tab UI (arrow keys, Home/End) once it connects; the content must render correctly with JS off.

## What does not belong in `app/`

No new settings screen, scope picker, or wizard — ease of use over configurability is the product rule, not a per-feature judgment call. No MCP tool that writes to a mailbox without going through `write_tool` on `McpTools::ApplicationTool`; there is no other sanctioned way for a tool to mutate mail.
