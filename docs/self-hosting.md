# Self-hosting mcp4mail

Run mcp4mail on your own machine or server and your IMAP credentials never leave it: they sit, encrypted,
in your own PostgreSQL and are used only to talk to your own mail provider.

## Quick start with Docker Compose

```bash
git clone https://github.com/jchsoft/mcp4mail.git
cd mcp4mail
cp .env.example .env     # fill in the values below
docker compose up -d
```

This builds the production image and starts two containers: `app` (Rails behind Thruster, with Solid Queue
running inside Puma) and `db` (PostgreSQL 17). On boot the app creates and migrates its four databases
(primary, cache, queue, cable). Data lives in the `postgres` and `storage` volumes.

The app is published on `localhost:${MCP4MAIL_PORT}` (8080 by default) over plain HTTP. **Put a reverse
proxy that terminates TLS in front of it** (Caddy, nginx, Traefik, a Cloudflare tunnel): OAuth 2.1 and every
MCP client require https. The app assumes it runs behind such a proxy and marks its cookies secure.

Then open your public URL, create an account, connect a mailbox and follow the **Connect AI** page.

## Environment variables

| Variable | Required | What it is |
| --- | --- | --- |
| `HITCH_RESOURCE_URI` | yes | The public URL of the MCP endpoint, e.g. `https://mail.example.org/mcp`. See below. |
| `SECRET_KEY_BASE` | yes | Signs sessions and cookies. `openssl rand -hex 64`. |
| `MCP4MAIL_DATABASE_PASSWORD` | yes | Password of the `mcp4mail` PostgreSQL user. `openssl rand -hex 32`. |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | yes | Encrypts stored mailbox passwords. |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | yes | Generated together with the primary key. |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | yes | Generated together with the primary key. |
| `MCP4MAIL_DATABASE_HOST` | outside Compose | PostgreSQL host; Compose sets it to `db`. Empty means the local socket. |
| `MCP4MAIL_PORT` | no | Host port the app is published on (Compose only). Default `8080`. |
| `SOLID_QUEUE_IN_PUMA` | no | Run background jobs inside the web process. Compose sets it. |
| `RAILS_LOG_LEVEL` | no | Default `info`. |

Generate the three encryption values once, with any Ruby checkout of the app:

```bash
bin/rails db:encryption:init
```

or, without Ruby on the host, from the built image:

```bash
docker compose run --rm --no-deps app bin/rails db:encryption:init
```

**Back them up.** If they are lost, every stored mailbox password becomes unreadable and each mailbox has to be
connected again. If they leak together with a database dump, the mailbox passwords can be decrypted.

### `HITCH_RESOURCE_URI` must match your public URL exactly

This is the one setting that breaks everything when it is wrong. mcp4mail issues OAuth tokens whose audience
(RFC 8707) is this URI, and MCP clients (Claude, ChatGPT, Grok, Cursor) compare it with the URL they were
given. It is matched **exactly**: scheme, host, port and path.

- It is the URL users paste into their AI client, including the `/mcp` path: `https://mail.example.org/mcp`.
- `https`, not `http`. Plain http is only accepted for `localhost` in development.
- No trailing slash, no extra port unless clients really use one, the same host name your proxy serves.
- If you move the app to a new domain, change it and have every client reconnect.

If it does not match, the app starts normally and the web UI works, but **no MCP client will connect**: the
client either rejects the server's metadata or gets its tokens refused. When a client fails during or right
after the OAuth flow, check this variable first.

Without the variable the app falls back to `https://mcp4mail.online/mcp`, the hosted instance, which is never
right for a self-hosted one.

## Running without Docker

Any host with Ruby (see `.ruby-version`) and PostgreSQL works:

```bash
bundle install
RAILS_ENV=production bin/rails assets:precompile
RAILS_ENV=production bin/rails db:prepare
RAILS_ENV=production SOLID_QUEUE_IN_PUMA=true bin/rails server
```

with the variables above in the environment. The PostgreSQL user is `mcp4mail` and needs permission to create
the `mcp4mail_production*` databases, or you create them yourself.

## Email

The app sends password-reset emails. No SMTP server is configured out of the box; set
`config.action_mailer.smtp_settings` and `default_url_options` in `config/environments/production.rb` for
your provider if you need them.

## Security notes

- **How credentials are stored.** A mailbox password is encrypted with Active Record Encryption (AES-256-GCM)
  before it is written to PostgreSQL, using the keys above. It is decrypted only in memory, to open the IMAP
  connection, and is never shown in the UI, returned by an MCP tool, written to the audit log or logged.
- **Use an app-specific password.** Gmail, iCloud, Fastmail, Outlook.com, Yahoo and others offer them. It can
  be revoked on its own, without changing your main password, and it does not unlock the rest of your account.
- **Read-only.** The MCP endpoint can list, search and read mail; nothing can send, move, delete or re-flag a
  message. See the README.
- **Keep secrets out of git.** `.env` is git-ignored. Never commit it, `config/master.key`, a real mailbox host
  or a database dump.
- **Backups.** A database backup contains the encrypted passwords; keep the encryption keys in a separate place.
