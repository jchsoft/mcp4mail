# Backlog refill log

The weekly backlog refill (mcptask.online task #13603) scans the sources below and files what
passes as subtasks of a Story `Backlog refill <ISO week>`. This file records each run's baseline,
so the next run knows where "since the last refill" starts and which findings were dropped by the
10-task cap and are worth checking again.

## How each source is measured

| Source | Command / check |
| --- | --- |
| Test coverage | `COVERAGE=1 CI=true bin/rails test:all`, then per-file line coverage from `coverage/.resultset.json` (minimum in `.simplecov`) |
| Ruby deps | `bundle outdated --strict --only-explicit`, `bin/bundler-audit update && bin/bundler-audit`, `bin/brakeman` |
| JS deps | `bin/importmap audit`, `bin/importmap outdated` |
| i18n parity | `i18n-tasks missing` / `i18n-tasks unused` |
| Accessibility | the axe system tests listed in [accessibility/axe-report.md](accessibility/axe-report.md), which run in the full suite |
| Dead code | `bin/rails routes` vs. usage, `debride --rails app lib` (`gem install debride`; it does not read Slim views, so check each candidate with `grep -rnw` over `app config lib`) |
| Docs drift | `ENV` reads in `app/`, `config/`, `lib/` vs. `.env.example` and [self-hosting.md](self-hosting.md), README tool table vs. `app/tools/mcp_tools/` |
| Dogfooding | about 10 realistic queries over MCP against the live server |
| MCP spec | https://modelcontextprotocol.io/specification/versioning and the current revision's changelog vs. `Hitch::MCP::Protocol::VERSION` |
| IMAP compatibility | Dovecot, Cyrus, Courier, Gmail, iCloud, Seznam, Zoho, Fastmail, Centrum, Outlook.com, Proton Bridge, Mailcow, Stalwart: a guide in `app/views/guides/content/` or a status in [self-hosting.md](self-hosting.md), and a test in `test/` |
| GitHub inbox | `gh issue list`, `mcptask_runner pr list --open`, `gh api repos/jchsoft/mcp4mail/dependabot/alerts?state=open` |
| Test suite health | `bin/rails test:all -v` three times, then per-test times and results from the logs. Through `/test-runner`, prefix variables with `env` (`env COVERAGE=1 CI=true bin/rails test:all -v`) |
| Production signals | `sync_errors` in `list_mail_accounts`, exception mails, Solid Queue failed jobs on the server when the solver has access; otherwise ask the owner in the Story message |

Monthly sources run one per refill, in the rotation listed in the refill task. The latest run's **Monthly source** line says which one ran. Each run also lists its dogfooding queries, so the next one does not repeat them. Write them generically: this repo is public, so no real names, addresses or subjects.

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

### 2026-W43 (2026-10-19, main @ 99d474f)

Story #13931, ten subtasks #13932–#13941.

- MCP spec: still revision **2026-07-28**, nothing new to evaluate.
- Coverage: 99.52 % lines / 90.23 % branches (minimum 99.0 / 89.3); no `app/` file below 98 %.
- i18n: `missing` and `unused` both clean. Accessibility: axe system tests green.
- Dead code: the only real `debride` hit was `AccountExportFile.sweep`, which nothing schedules (#13932).
- Dogfooding: 12 queries; four issues filed (folder roles, folder names, `from:` operators, Czech
  inflection).
- Skipped as duplicates: thruster 0.1.27 (#13890) and the undocumented `JOB_CONCURRENCY`,
  `WEB_CONCURRENCY`, `RAILS_MAX_THREADS` (part of the self-hosting dry run #13885).
- Nothing dropped by the cap.

### 2026-W44 (2026-10-22, main @ 459b327)

Story #14076, one subtask #14077. Named W44: the W43 refill had already run, and this one is due 2026-10-26.

- MCP spec: still revision **2026-07-28**, nothing new to evaluate.
- Coverage: 99.52 % lines / 90.30 % branches (minimum 99.0 / 89.3); no `app/` file below 98 %.
- Ruby and JS deps, Brakeman, i18n `missing` / `unused`, axe system tests: all clean.
- Dead code: every `debride` candidate is used; `AccountExportFile.sweep` is now in `config/recurring.yml`.
- Dogfooding: 16 queries. New: the index never refreshes flags (or drops expunged mail) after the first
  import, so `unread: true` lists mail read elsewhere (#14077). `from:` operators and `folder: "Sent"`
  still fail live only because `production` (e292e83) predates their fixes on `main`; raised with the
  owner, not filed.
- Skipped as duplicates: undocumented `JOB_CONCURRENCY`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS` (#13885),
  Gmail compatibility status (live check #13330).
- Nothing dropped by the cap.

### 2026-W45 (2026-10-26, main @ dcbef75)

Story #14124, no subtasks: the one finding was fixed in the refill PR itself. Named W45: the W44 refill had already run on 2026-10-22.

- MCP spec: still revision **2026-07-28**, nothing new to evaluate.
- Coverage: 99.52 % lines / 90.30 % branches (minimum 99.0 / 89.3); no `app/` file below 98 %.
- Ruby deps: `crass 1.0.7` has advisory GHSA-pq4g-8rxf-4g29 (CSS sanitizer bypass, fixed in 1.0.8), published
  2026-10-23. Local `bin/bundler-audit` missed it because its advisory DB was stale; only the PR's
  `scan_ruby` check caught it. Bumped to 1.0.8 in the refill PR, since the red check blocked every PR.
  Run `bin/bundler-audit update` before the audit from now on.
- JS deps, Brakeman, i18n `missing` / `unused`, axe system tests: all clean.
- Dead code: every `debride` candidate is used.
- Dogfooding: 11 queries, all correct. `from:` operators and `folder: "Sent"` now work live, so
  `production` has caught up with the W43 fixes.
- Skipped as duplicates: undocumented `JOB_CONCURRENCY`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS` (#13885),
  stale unread state (#14077), Gmail compatibility status (live check #13330).
- Nothing dropped by the cap.

### 2026-W46 (2026-11-02, main @ 257b72d)

Story #14515, four subtasks #14516–#14519. Named W46: a Story `Backlog refill 2026-W45` already exists from 2026-10-26, and this run is due 2026-11-09.

- MCP spec: still revision **2026-07-28**, nothing new to evaluate.
- Coverage: 99.52 % lines / 90.30 % branches (minimum 99.0 / 89.3); no `app/` file below 98 %.
- Ruby deps: `addressable 2.9.0` has seven advisories, all fixed in 2.9.1. Bumped to 2.9.2 in the refill PR,
  since `bundler-audit` fails `bin/ci` and `scan_ruby` for every PR. Filed: `tailwindcss-rails 4.7.0`,
  `selenium-webdriver 4.52.0`, patch bumps `nokogiri 1.19.5` and `bootsnap 1.26.1`.
- JS deps, Brakeman, i18n `missing` / `unused`, axe system tests: all clean.
- Dead code: every `debride` candidate is used.
- Dogfooding: 17 calls. New: "faktura" misses a subject with "fakturu", because the prefix-stem match decided in
  #13936 ([decisions-czech-search.md](decisions-czech-search.md)) was never implemented or filed (#14519). Stale
  unread state still shows: a folder listing reports 0 unseen where a search marks the same mail unread.
- Skipped as duplicates: undocumented `JOB_CONCURRENCY`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS` (#13885),
  stale unread state (#14077), Gmail compatibility status (live check #13330).
- Nothing dropped by the cap.

### 2026-W46 extended (2026-11-02, main @ 8c8581b)

Story #14528, ten subtasks #14529–#14537 and #14539. A second refill due 2026-11-09, from #14514, whose procedure is newer
than the one #14513 followed an hour earlier. Name the next Story after its due date's week as usual (W47 for 2026-11-16).

- MCP spec: still revision **2026-07-28**, nothing new to evaluate.
- Coverage: 99.52 % lines / 90.30 % branches (minimum 99.0 / 89.3), 0.52 % above the line minimum; lowest `app/` file 98.4 %.
- Ruby deps: no advisories, Brakeman clean. Already filed: `tailwindcss-rails 4.7.0` (#14516), `selenium-webdriver 4.52.0`
  (#14517), patch bumps (#14518, PR #206, now `nokogiri 1.19.6`).
- JS deps, i18n `missing` / `unused`: clean. Dead code: same `debride` candidates as this morning; the only change on `main`
  since then is the `addressable` bump and the run log, so they were not re-checked by grep.
- Docs drift: no new undocumented env vars. See the monthly source for what the self-hosting docs get wrong.
- IMAP compatibility: first run over the wider host list. Filed Outlook.com (#14531, the README and the connect error
  disagree), Centrum (#14532), Proton Bridge (#14533), Mailcow (#14534), Stalwart (#14535).
- GitHub inbox: no open issues, no open Dependabot alerts, no PRs from outside contributors. Dependabot PR #203 can be closed
  once #206 merges.
- Test suite health: 842 runs green three times, nothing flaky. Seven tests went over 5 s at least once:
  - `Smtp::AutodetectTest` "an address with no domain", 15.1 s, turned out to be a real bug: filed as #14539.
  - Dropped by the cap, check again: four `HeroDemoTest` tests at 15–18 s (375px en, 375px cs, 820px cs, "rewinds on connect"),
    `AccountExportTest` "Download my data" at 7.8 s, `SessionsTest` "rapid sign-in attempts" at 3.4–7.4 s.
- Production signals: no `sync_errors` on any connected account, and a search for "exception" found nothing, but the exception
  mails go to an address that is not connected. Solid Queue failed jobs not checked: no server access. Asked the owner.
- **Monthly source: self-hosting dry run, read only.** Docker is not installed on the audit machine, so nothing was executed.
  Reading `docs/self-hosting.md` against `docker-compose.yml` found two bugs: #14529 (empty error-mail recipients still mail the
  hosted operator) and #14530 (Compose requires the encryption keys the docs call optional). The full run stays with #13885.
  The next run takes the onboarding dry run.
- Dogfooding: 15 calls, read-only. Not timed: an MCP client call reports no duration, so the 3 s threshold was not measured. Queries:
  - `since` + `until` over one week, no query
  - `xlsx`, `ics` (attachments by type)
  - `Re: Re: Re:` (long threads, #14536)
  - contact: a surname without its diacritics; contact: name and domain together
  - `folder: "Junk"` where the server calls it `INBOX.Spam`
  - `objednavka`, `objednávky` (diacritics, inflection)
  - `invoice faktura` (mixed language)
  - `xyzzyqq nonexistent` (empty result)
  - `until` before `since`
  - `flagged` in `folder: "Archive"` (#14537)
  - `exception` since a date
  - `list_folders`
