# test

How this suite is written and run, for whoever adds the next test. Minitest, fixtures, no network: every IMAP server, DNS answer and HTTP autoconfig a test touches is a fake on `127.0.0.1`, and every address is made up.

## Layout, and which level a test belongs at

| Directory | What goes there |
| --- | --- |
| `models`, `services` (`services/imap`), `tools`, `jobs`, `mailers`, `helpers`, `lib` | Unit tests of the class of the same name under `app/` or `lib/` |
| `controllers` | One request, one response: status, redirect, flash, `assert_select` on the rendered HTML. Also the per-section landing tests (`how_section_test.rb`, `why_section_test.rb`, ...) |
| `integration` | Several requests in one story, or anything through the MCP endpoint and OAuth (`mcp_*_test.rb`, `hitch_*_test.rb`, `account_deletion_test.rb`) |
| `views/shared` | The shared partials rendered on their own (`_alert`, `_field`, `_flash`, `_error_summary`) |
| `views` | View-level tests that are not about one partial: `shared_headers_test.rb` renders the two headers, `default_palette_test.rb` scans the markup for off-palette classes. |
| `system` | A real browser: JavaScript, layout, focus, what a person actually sees and clicks |
| `assets` | The stylesheet source (`tailwind_theme_test.rb`) and the image assets |
| `locales` | `locale_parity_test.rb`: `cs` and `en` carry the same keys |

Everything under `controllers` and `integration` subclasses `ActionDispatch::IntegrationTest`, so the split between them is about scope, not about which class you use.

The same journey is often covered at more than one level. Put each assertion at the lowest level that can see it:

- It is in the HTML the server sends → controller test. Fast, runs in parallel, and a wrong status or a missing `#connection-error` shows up here first.
- It needs more than one request, or the MCP/OAuth protocol → integration test.
- It needs JavaScript, CSS or a real layout (Stimulus behaviour, focus order, overflow, computed styles, screenshots) → system test.

A system test that only asserts text a controller test could have asserted is paying for a browser for nothing. Keep system tests to the journey itself (sign up → add a mailbox → connect the AI) and to what only a browser can measure.

## Fixtures, helpers, support

- `test/fixtures`: `users.yml` (`one`, `two`, both with the password `password`) and `mail_accounts.yml` (`work` for `one`, `personal` for `two`, on `imap.example.com`/`.net`). `fixtures :all` loads them for every test. A fixture mailbox points at a host that does not exist; a test that needs IMAP to answer builds its own account against a `FakeImapServer` port.
- `test/test_helpers/session_test_helper.rb`: `sign_in_as(user)` / `sign_out`, included into every integration test. System tests sign in through the form instead.
- MCP requests: integration tests `require "hitch/mcp/test_helper"` and `include Hitch::MCP::TestHelper` for `mint_mcp_token(principal:)` and `post_mcp(method:, token:, params:)`. Tests that hit the quota set `McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new` in `setup` so counts do not leak between tests.
- `test/support/fake_imap_server.rb`: `FakeImapServer`, a small real-socket IMAP server on `127.0.0.1` with a random port. Describe the mailbox with `folders:` and `mailboxes:` (see the comment at its top), `start` it, point an account at `server.port`, and `stop` it in `ensure`. It records `commands` and `fetched_uid_sets` for assertions.
- `test/support/fake_autodetect_network.rb`: `FakeAutodetectNetwork`, doubles for the HTTP, DNS and IMAP that `Imap::Autodetect` talks to. Include it and describe the world with `autoconfig`, `dns` and `imap`. Minitest 6 has no `Object#stub`; this module does the swap itself.

### Making IMAP fail on purpose

Every failure is produced locally, never by reaching the network:

- Wrong password: `FakeImapServer.new(login_ok: false).start`: `LOGIN` answers `NO`.
- Unreachable host: start a server, keep its `port`, `stop` it, then connect to that port: `Errno::ECONNREFUSED` without a timeout.
- TLS against a plaintext endpoint: `FakeImapServer.tls_trap` answers in plaintext while the client expects TLS, so the handshake raises `OpenSSL::SSL::SSLError`.
- A crash mid-sync: `drop_on_fetch_of: <uid>` closes the connection when that UID is fetched.
- A server that refuses writes or folder creation: `refuse_store: true`, `namespace_prefix: "INBOX."`.

## System tests

`ApplicationSystemTestCase` (`test/application_system_test_case.rb`) fixes the browser:

- Selenium with `headless_firefox`, `screen_size: [1400, 1400]`.
- `intl.accept_languages = "en"`: pages follow `Accept-Language`, so the browser is pinned to English rather than the machine's locale. Test Czech by passing it in the URL: `visit root_url(locale: :cs)`.
- `parallelize(workers: 1)`: eight Firefoxes at once dropped clicks and sign-ins. The unit suite keeps its workers; only the browsers run one at a time.
- If `app/assets/builds/tailwind.css` is missing (e.g. after `bin/ci` clobbered it), the class builds it before running, so a single system file still runs against real CSS.

**Narrow widths.** Headless Firefox will not make a window narrower than about 500 CSS px, so a resized "375px" test really measures 500px. `landing_responsive_test.rb` and `hitch_screens_phone_test.rb` load the page inside an iframe `#viewport` of the exact width instead: an iframe is its own viewport, so `vw`, `clamp()` and media queries resolve against 375. Use that pattern for anything below ~500px.

**Screenshots.** `screenshot!("<area>-<screen>-<locale>[-<width>]")`, e.g. `screenshot!("landing-hero-cs")` or `screenshot!("hitch-consent-en-375")`. The name is the file's whole identity (no timestamps, no counters), so a capture can be diffed against the same capture from the last run; the same name overwrites. Files land in `tmp/screenshots` next to Rails' automatic failure screenshots, and CI uploads that directory as an artifact on every run. Captures are taken whether the test passes or fails, so they are the review material for a visual change, not only a debugging aid. `screenshot_path(name)` gives the path when you write the file yourself (`landing_responsive_test.rb` does).

## Running them

- Through the `test-runner` skill: unit (`bin/rails test`), system (`bin/rails test:system`), or one file.
- `bin/ci` before any PR (`config/ci.rb`): RuboCop, audits, Brakeman, `bin/rails test`, `bin/rails test:system`, seeds. Run it through the `ci-runner` skill. It posts the signoff only when it exits 0.
- On GitHub, `test` and `system-test` are two of the five required checks (with `scan_ruby`, `scan_js`, `lint`). A red system test blocks the merge like any other.

## Brittle selectors

A restyle may change every class around these, but not these. They are listed in `app/views/CLAUDE.md` and `docs/design/GUIDELINES.md` §8 for whoever edits markup; they are here for whoever writes tests. Assert on them and nothing more fragile:

- DOM ids: `#empty` `#errors` `#connection-error` `#no-mailbox` `#alert` `#notice` `#server-url` `#language-switcher`.
- `main section:first-of-type`: the landing hero is the first `<section>` in `<main>`.
- `find("summary", text: "Recent activity")` in `mailbox_activity_test.rb`: the per-mailbox activity is a `<details>` with one `<li>` per entry.
- `fill_in placeholder: "Enter your email address"` / `"Enter your password"` on `sessions/new`.

Prefer roles and visible text (`click_button "Sign in"`, `assert_selector "h1"`) to classes. Never assert on a Tailwind class: those are the first thing a restyle changes. If a new test needs a hook, add an id of a stable meaning and add it to all three lists.

## Assertions about the design

`test/assets/tailwind_theme_test.rb` pins every token value in the `@theme` block of `app/assets/tailwind/application.css`, and `test/system/design_tokens_test.rb` checks in the browser that pages actually render on them (paper background, Instrument Sans, and the signed-in shell — `main#main` in the 1160px column, the app header on the same gutter, the skip link off-screen until focused). `test/views/default_palette_test.rb` is the third guard: it reads `app/views/**/*.erb` and `app/helpers/**/*.rb` for a built-in Tailwind hue (`text-red-700`, `divide-gray-200`) and fails on the class itself, so an off-palette utility is caught where it is typed rather than in a screenshot. A design change that moves a token without updating the first two, and the reason in the comment beside the value, is not finished.
