# mcp4mail

## McpTask.online
- Project name: mcp4mail.online
- project_relative_id=74
- account_code: `jchsoft`

## What this is
Your mailbox as an MCP server: connect an IMAP account and an AI assistant reads and searches your mail, authorized over OAuth 2.1. Hosted at mcp4mail.online, open source (MIT) and self-hostable. See [README.md](README.md).

Product rules that decide feature arguments:
- Free and open source; it will not be monetized.
- Ease of use beats configurability. A feature that needs a settings screen, a scope picker or a multi-step wizard is cut or made automatic.
- The target user is on their own IMAP host, which is why there is no Gmail or Microsoft OAuth. Plain IMAP with username + app password.

## Stack
Rails 8, PostgreSQL, Hotwire (Turbo + Stimulus), propshaft, minitest, Solid Queue/Cache/Cable. `hitch-rails` provides OAuth 2.1 and the MCP transport.

Tailwind v4 is CSS-first: tokens live in `app/assets/tailwind/application.css` (`@theme`). There is no `tailwind.config.js`; do not create one.

## Running things
- `bin/dev` starts the dev stack from `Procfile.dev` (web + the Tailwind css watcher). `bin/setup` for first run.
- `bin/ci` must pass before any PR (rubocop, audits, Brakeman, tests, system tests, seeds).
- Run tests through the `test-runner` skill, CI through `ci-runner`.
- Self-hosting and env vars: [docs/self-hosting.md](docs/self-hosting.md). Contributor rules: [CONTRIBUTING.md](CONTRIBUTING.md).

## Repo rules
- Public repo. `main` is protected: PR only, squash merges, linear history. Never push to `main`.
- Required checks: `scan_ruby`, `scan_js`, `lint`, `test`, `system-test` (`.github/workflows/ci.yml`).
- `production` is the branch that deploys.

## Secrets
Never commit `config/master.key`, `.env*`, `credentials.yml`, real mailbox hosts/usernames or dumps; they are git-ignored. `.env.example` lists the variables (`HITCH_RESOURCE_URI`, `SECRET_KEY_BASE`, database password, the three `ACTIVE_RECORD_ENCRYPTION_*` keys, `MCP4MAIL_PORT`) with empty values. Production secrets come from the environment; dev/test derive throwaway encryption keys from `tmp/local_secret.txt`. Tests use fake servers on `127.0.0.1` and made-up addresses.

## MCP endpoint is read-only by design
Every mailbox is read-only unless its owner turns on the per-account "Allow the AI to make changes" switch. A tool that writes to a mailbox is not added without an explicit decision; the tool registry refuses to boot with a tool that is neither read-only and non-destructive nor declared via `write_tool destructive: ...` on `McpTools::ApplicationTool`. Every tool resolves data through the signed-in user's own mail accounts.

## Locales
`cs` and `en` are both first-class. Every user-facing string goes through I18n and is translated in both (`config/locales/`).

## Pointers
- Anything visual: `docs/design/` (`GUIDELINES.md` once present, otherwise its `README.md`).
- [docs/self-hosting.md](docs/self-hosting.md), [docs/accessibility/axe-report.md](docs/accessibility/axe-report.md).
- Per-folder `CLAUDE.md` files (added by sibling tasks) carry the local conventions.
