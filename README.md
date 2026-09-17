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

## License

[MIT](LICENSE)
