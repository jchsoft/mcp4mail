# mcp4mail

Your mailbox as an [MCP](https://modelcontextprotocol.io) server. Connect an IMAP account and let your AI
assistant read and search your mail, authorized over OAuth 2.1. Hosted at
[mcp4mail.online](https://mcp4mail.online), open source and self-hostable.

**Run it yourself and your credentials never leave your machine.** A hosted mail connector necessarily keeps
your IMAP password on someone else's server; with mcp4mail you can keep it in your own database instead. One
`docker compose up` gets you there: see the [self-hosting guide](docs/self-hosting.md).

> Early days: the MCP endpoint lists your connected accounts; reading and searching mail is next.

This project is primarily developed by AI developers orchestrated through
[mcptask.online](https://mcptask.online). Watch the development happen live: https://mcptask.online/live

## How this project is built

This is a real open-source product and, at the same time, a public demonstration. Tasks are written by
people in [mcptask.online](https://mcptask.online), picked up by runners (Claude Code driven by the
mcptask runner, on our own machines), and every change follows the same path: task → branch → pull request
→ tests & CI → merge → deploy to [mcp4mail.online](https://mcp4mail.online). Nobody, person or runner,
pushes to `main` directly: the branch is protected by a repository ruleset that requires an open pull
request, a linear history, and green status checks (security scans, lint, unit tests, system tests) before
a squash merge is allowed.

Watch it live: https://mcptask.online/live

Where to look if you want to verify any of this yourself: the [Pull requests](../../pulls) tab, where each
PR links its task and shows its CI runs, including the failed ones; [CLAUDE.md](CLAUDE.md) and
[`.claude/`](.claude), the instructions the runners work from; and the
[CI configuration](.github/workflows/ci.yml).

People still write the task briefs, review the pull requests, and decide what ships and what doesn't; a
runner executes a task end to end, but it is not deciding what to build. A runner is a user with a seat
here, not something free or unlimited.

## MCP tools

| Tool | What it does |
| --- | --- |
| `list_mail_accounts` | Lists the mail accounts you connected, with the ids the other tools take. |
| `get_mail_account` | Shows the connection details of one account (never its password). |
| `list_folders` | Lists the folders of one account. |
| `search_messages` | Searches by subject, sender, recipients and date. |
| `get_message` | Reads one message. |
| `get_attachment` | Downloads an attachment of a message: a short-lived link, or with `inline: true` the file itself (up to 5 MB) inside the MCP answer. |
| `search_contacts` | Finds addresses you have corresponded with. |
| `get_outgoing_status` | Tells whether an email handed to `send_message` has gone out. |
| `set_flags` | Flags a message or marks it read / unread. *Write.* |
| `move_message` | Moves a message to another folder. *Write.* |
| `trash_message` | Moves a message to Trash. *Write.* |
| `create_folder` | Creates a folder. *Write.* |
| `create_draft` | Saves a draft. *Write.* |
| `send_message` | Prepares an email; it is sent only after you approve it. *Write.* |

Write tools work only on a mailbox whose owner switched on "Allow the AI to make changes to this mailbox";
everywhere else they are refused, see [below](#mcp-endpoint-read-only-by-design). `send_message` never sends
on its own: you get an email with a link and the message leaves only when you press Send.

## Self-hosting

```bash
cp .env.example .env    # fill in the values
docker compose up -d
```

Read [docs/self-hosting.md](docs/self-hosting.md) first: which environment variables matter, why
`HITCH_RESOURCE_URI` must match your public URL exactly, TLS, and how mailbox passwords are stored.

## Stack

Ruby 3.4, Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind CSS, Solid Queue / Cache / Cable.

## Development

```bash
bin/setup   # install gems, prepare the database, start the dev server
bin/dev     # web server + Tailwind watcher
bin/ci      # rubocop, security audits, tests, system tests
```

PostgreSQL must be running locally; the default config connects over the local socket as your OS user.

## Secrets

This repository is public. Nothing secret is ever committed: `config/master.key`, `.env*` and
`credentials.yml` are git-ignored, production secrets come from the environment.

Mailbox passwords are encrypted at rest with Active Record Encryption. In production, generate keys with
`bin/rails db:encryption:init` and provide them through the encrypted credentials
(`active_record_encryption.*`) or the `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` environment
variables. Development and test derive throwaway keys from the per-machine `tmp/local_secret.txt`.

## Mail accounts

mcp4mail connects to your mailbox over plain IMAP with a username and password. **Use an app-specific
password wherever your provider offers one** (Gmail, iCloud, Fastmail, Outlook.com, Yahoo and others do), so
that what is stored in the database can be revoked on its own and is not the key to your whole account.
How the password is stored and who can decrypt it is described in the
[security notes of the self-hosting guide](docs/self-hosting.md#security-notes).

## MCP endpoint: read-only by design

Every mailbox is read-only until you say otherwise. Each mailbox on the Mail accounts page has one switch,
"Allow the AI to make changes to this mailbox", and it is off by default. No scopes, no per-tool
permissions: that switch is the whole opt-in.

- **Off** (the default): the AI can only read and search. Any tool that would change the mailbox is refused
  with a message telling the model the mailbox is read-only, and the refusal is written to the audit log as
  `denied`.
- **On**: tools that change mail (flag, move, draft and, with your approval, send) may act on that mailbox.

The tool registry refuses to boot with a tool that is neither read-only and non-destructive nor explicitly
declared as a write tool (`write_tool destructive: ...` on `McpTools::ApplicationTool`), so nothing can
slip in as a write tool by accident. Write tools announce `readOnlyHint: false` and declare their own
`destructiveHint`.

What read-only does and does not mean, plainly:

- Nothing can change a mailbox without its switch. Folders are opened with IMAP `EXAMINE`, so even reading
  does not mark messages as seen.
- It does read your mail, whenever an AI client you connected asks. Connect only clients you trust with that.
- It keeps a copy of message headers (sender, recipients, subject, date, flags, size) in its own database,
  refreshed every 15 minutes, so searches do not hit your mail server each time.

- **Scoping.** Every tool resolves data through the signed-in user's own mail accounts; an account id that is
  not theirs is refused before any tool code runs.
- **Rate limits.** Hitch limits each user + client pair (120 requests a minute); on top of that each user has
  one quota for tool calls across all their clients (240 a minute).
- **Audit log.** Every call is written to `mcp_audit_events`: user, client, tool, account, outcome, rows
  returned, duration. Arguments are not stored.
- **Search guard.** Pages are capped at 50 results, and each account has a budget of searches (60 per
  10 minutes) and returned rows (1,000 an hour), so a runaway loop cannot walk a whole mailbox.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). `bin/ci` must pass.

## License

[MIT](LICENSE)
