# mcp4mail

Your mailbox as an [MCP](https://modelcontextprotocol.io) server. Connect an IMAP account and let your AI
assistant read and search your mail, authorized over OAuth 2.1. Hosted at
[mcp4mail.online](https://mcp4mail.online), open source and self-hostable.

> Early days: this is the application skeleton. The MCP endpoint and mail accounts are not there yet.

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

## License

[MIT](LICENSE)
