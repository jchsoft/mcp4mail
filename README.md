# mcp4mail

Your mailbox as an [MCP](https://modelcontextprotocol.io) server. Connect an IMAP account and let your AI
assistant read and search your mail, authorized over OAuth 2.1. Hosted at
[mcp4mail.online](https://mcp4mail.online), open source and self-hostable.

> Early days: the MCP endpoint lists your connected accounts; reading and searching mail is next.

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

## MCP endpoint: read-only by design

The first release only reads: no tool sends, moves, deletes or re-flags mail, and the tool registry refuses
to boot with a tool that does not declare itself read-only. Write tools may come later, behind an explicit
per-account opt-in.

- **Scoping.** Every tool resolves data through the signed-in user's own mail accounts; an account id that is
  not theirs is refused before any tool code runs.
- **Rate limits.** Hitch limits each user + client pair (120 requests a minute); on top of that each user has
  one quota for tool calls across all their clients (240 a minute).
- **Audit log.** Every call is written to `mcp_audit_events`: user, client, tool, account, outcome, rows
  returned, duration. Arguments are not stored.
- **Search guard.** Pages are capped at 50 results, and each account has a budget of searches (60 per
  10 minutes) and returned rows (1,000 an hour), so a runaway loop cannot walk a whole mailbox.

## License

[MIT](LICENSE)
