# Backlog refill log

The weekly backlog refill (mcptask.online task #13603) scans the sources below and files what
passes as subtasks of a Story `Backlog refill <ISO week>`. This file records each run's baseline,
so the next run knows where "since the last refill" starts and which findings were dropped by the
10-task cap and are worth checking again.

## How each source is measured

| Source | Command / check |
| --- | --- |
| Test coverage | `COVERAGE=1 CI=true bin/rails test:all`, then per-file line coverage from `coverage/.resultset.json` (minimum in `.simplecov`) |
| Ruby deps | `bundle outdated --strict --only-explicit`, `bin/bundler-audit`, `bin/brakeman` |
| JS deps | `bin/importmap audit`, `bin/importmap outdated` |
| i18n parity | `i18n-tasks missing` / `i18n-tasks unused` (not installed yet, see W42) |
| Accessibility | the axe system tests listed in [accessibility/axe-report.md](accessibility/axe-report.md), which run in the full suite |
| Dead code | `bin/rails routes` vs. usage, `debride` |
| Docs drift | `ENV` reads in `app/`, `config/`, `lib/` vs. `.env.example` and [self-hosting.md](self-hosting.md), README tool table vs. `app/tools/mcp_tools/` |
| Dogfooding | about 10 realistic queries over MCP against the live server |
| MCP spec | https://modelcontextprotocol.io/specification/versioning and the current revision's changelog vs. `Hitch::MCP::Protocol::VERSION` |
| IMAP compatibility | Dovecot, Cyrus, Courier, Gmail, iCloud, Seznam, Zoho, Fastmail: a guide in `app/views/guides/content/` and a test in `test/` |

## Runs

### 2026-W42 (2026-10-12, main @ 168b857)

Story #13671, ten subtasks #13672–#13681.

- MCP spec baseline: revision **2026-07-28**, which hitch-rails 0.5.0 speaks. The next run reads
  the changelog of any revision newer than that.
- Coverage: 99.51 % lines / 89.86 % branches (minimum 99.0 / 89.3); no `app/` file below 95 %.
- Not measured: dead code (`debride` not installed) and i18n `unused` (`i18n-tasks` not installed,
  filed as #13675).
- Dropped by the cap, check again: `imap: cyrus`, `imap: courier`, `imap: zoho`, `imap: fastmail`,
  patch bump `thruster 0.1.27`.
