# axe-core accessibility report — mcp4mail.online landing page

Run by test/system/landing_accessibility_test.rb on task #12708.
Tags: wcag2a, wcag2aa, wcag21a, wcag21aa. Viewport 1400x1400, headless Firefox.

## locale: en  (http://127.0.0.1:56474/?locale=en)

axe-core 4.13.0 · 2026-09-18T16:59:17.117Z

| passes | violations | incomplete | inapplicable |
|---|---|---|---|
| 25 | 0 | 1 | 37 |

### violations
**none** — no serious or critical issues outstanding.

### incomplete (axe could not decide; checked by hand)
- color-contrast: Elements must meet minimum color contrast ratio thresholds
    <span class="bg-[linear-gradient(transparent_62%,var(--color-highlight)_62%)]">readable</span>

### rules passed
aria-allowed-attr, aria-conditional-attr, aria-deprecated-role, aria-hidden-body, aria-hidden-focus, aria-prohibited-attr, aria-required-attr, aria-required-children, aria-roles, aria-valid-attr, aria-valid-attr-value, bypass, color-contrast, document-title, html-has-lang, html-lang-valid, image-alt, link-in-text-block, link-name, list, listitem, meta-viewport, nested-interactive, summary-name, valid-lang

## locale: cs  (http://127.0.0.1:56474/?locale=cs)

axe-core 4.13.0 · 2026-09-18T16:59:17.635Z

| passes | violations | incomplete | inapplicable |
|---|---|---|---|
| 25 | 0 | 1 | 37 |

### violations
**none** — no serious or critical issues outstanding.

### incomplete (axe could not decide; checked by hand)
- color-contrast: Elements must meet minimum color contrast ratio thresholds
    <span class="bg-[linear-gradient(transparent_62%,var(--color-highlight)_62%)]">srozumitelná</span>

### rules passed
aria-allowed-attr, aria-conditional-attr, aria-deprecated-role, aria-hidden-body, aria-hidden-focus, aria-prohibited-attr, aria-required-attr, aria-required-children, aria-roles, aria-valid-attr, aria-valid-attr-value, bypass, color-contrast, document-title, html-has-lang, html-lang-valid, image-alt, link-in-text-block, link-name, list, listitem, meta-viewport, nested-interactive, summary-name, valid-lang
## The one incomplete result, resolved by hand

Both locales leave the same single node undecided: the hero's highlighted word,
whose "marker pen" effect is a `linear-gradient` rather than a flat colour, so
axe cannot read a background out of it and declines to judge the pair.

Measured directly, the span is `#1f2430` over two grounds:

- on the highlight `#ffd166` below the 62% stop — **10.76:1**
- on the paper `#fbf8f3` above it — **14.65:1**

Both pass AA comfortably. Nothing to fix.

## Palette pairs measured by hand on this task

| pair | where | before | after |
|---|---|---|---|
| `#1f2430` on `#f26b1d` | primary CTA label | 5.10 | 5.10 (unchanged, as briefed) |
| `#1f2430` on brand hover | CTA label, hover | 4.37 ✗ | 5.66 (`--color-brand-hover` → `#f5792f`) |
| kicker on `#fbf8f3` | five section kickers, nav hover | 4.43 ✗ | 5.02 (`--color-brand-deep` → `#bc430f`) |
| muted grey on `#fbf8f3` | hero note, client row, footer — all 13-14px | 4.56 (borderline) | 5.78 (`--color-ink-muted` → `#5c626e`) |
| green link on `#fbf8f3` | footer links | 4.02 ✗ | 4.95 (`--color-green` → `#1a7a63`) |
| `#ffffff` on green | "watch it live" pill, step-3 badge | 4.26 ✗ | 5.24 (same token change) |
| `#15654f` on `#dff3ec` | hero badge | 6.04 | unchanged |
| `#cfd3dc` on `#1f2430` | dark panel body | 10.35 | unchanged |
| `#ffd166` on `#1f2430` | dark panel kicker and links | 10.76 | unchanged |
| `#4a515f` on `#fbf8f3` / `#ffffff` / `#fde9dc` | body copy | 7.53 / 7.97 / 6.78 | unchanged |
| focus ring on `#fbf8f3` | whole light page | 2.87 ✗ | 14.65 (ink outline) |
| focus ring on `#fde9dc` | closing CTA panel | 2.59 ✗ | 13.20 (ink outline) |
| focus ring on the green pill | "watch it live" | 1.72 ✗ | 5.24 (ink outline) |
| focus ring on `#1f2430` | dark Security panel | 5.10 | 5.10 (orange inner ring) |

## Danger and form-field tokens (task #12800)

These tokens had no design value to start from; each was chosen against both
light grounds, `paper` `#fbf8f3` and `surface` `#ffffff`. Text and icon colours
clear 4.5:1, component edges 3:1.

| pair | where | on paper | on surface |
|---|---|---|---|
| `--color-danger` `#b8321c` as text | error text, destructive link | 5.65 | 5.98 |
| `#ffffff` on `--color-danger` | destructive button label | — | 5.98 |
| `#ffffff` on `--color-danger-deep` `#8f2613` | destructive button label, hover | — | 8.56 |
| `--color-danger-deep` as text | error text needing extra weight | 8.08 | 8.56 |
| `--color-danger-deep` on `--color-danger-tint` `#fbe3dc` | error alert text | 6.98 (on tint) | — |
| `--color-danger` on `--color-danger-tint` | error alert icon, border | 4.88 (on tint) | — |
| `#1f2430` on `--color-danger-tint` | error alert body copy | 12.65 (on tint) | — |
| `--color-danger-tint` against the ground | error alert fill | 1.16 | 1.23 |
| `--color-field-border` `#8a8378` | input, select, textarea edge | 3.54 | 3.75 |
| `--color-field-placeholder` `#6f6a63` | placeholder text | 5.06 | 5.36 |

The tint is a fill, not a boundary: at 1.16:1 it cannot mark an alert's edge by
itself, so an alert on the tint carries a `danger` border (4.88:1 against the
tint) and its message in text.

## The badge (task #12821)

`shared/_badge` reuses the families above; only the green pair was not already
measured. The badge appears on `paper` today and on `surface` once the mailbox
list becomes cards, so both grounds are given.

| pair | where | on paper | on surface |
|---|---|---|---|
| `--color-green-deep` `#15654f` on `--color-green-tint` `#dff3ec` | `:ok` label | 6.04 (on tint) | — |
| `--color-green` `#1a7a63` on `--color-green-tint` | `:ok` border | 4.53 (on tint) | — |
| `--color-danger-deep` on `--color-danger-tint` | `:denied` label | 6.98 (on tint) | — |
| `--color-danger` on `--color-danger-tint` | `:denied` border | 4.88 (on tint) | — |
| `--color-ink-soft` `#4a515f` on `--color-surface-hover` `#f1ebe1` | `:neutral` label | 6.73 (on fill) | — |
| `--color-surface-hover` against the ground | `:neutral` fill | 1.12 | 1.19 |

The pill's outline is decoration, not a boundary a person has to find: the word
or number inside it says the same thing at 6.0:1 or better, and the two verdict
variants carry an edge in their own family above 4.5:1 besides. That is why the
`:neutral` fill is allowed to sit at 1.12:1 against paper — nothing is lost if a
reader sees only the label.

## Signed-in screens (task #12827)

Run by `test/system/internal_accessibility_test.rb`. Tags and viewport match the
landing run above. The set of screens covered:

- sign-in (`/session/new`)
- registration (`/registration/new`)
- password request (`/passwords/new`)
- mailbox index (`/mail_accounts`)
- new-mailbox form (`/mail_accounts/new`), including the `#errors` and
  `#connection-error` paths
- activity frame (`/mail_accounts/:id/activity`), opened from the mailbox index
- connect-the-AI (`/connect-ai`)

The same `WCAG AA` and `BLOCKING_IMPACTS` filters apply, and the same rule: a
serious or critical axe finding fails the build, an incomplete one is resolved
by hand. The keyboard walk asserts the two-tone focus ring actually draws on
the Mailboxes nav link, the Add mailbox button, the Recent activity disclosure
and the Remove button — the global rule is in `application.css`, and these are
the controls that have historically overridden it.

Re-run with `bin/rails test:system test/system/internal_accessibility_test.rb`
and re-collect the run header / rule lists from axe the same way the landing
report does — the values above are landing-page specific.

## The guard's sweep (task #12825)

The regression guard for this story reads every view and helper for off-palette
classes, and checking what it left behind against this file turned up three
pairs in use that the tables above did not name: the dark pill's white label
(`#ffffff` on `ink` and on its `code-chip` hover) and the nav/tab label on its
`surface-hover` hover. A white label is right here and wrong on `brand` — rule
2.1 is about the ratio, not the colour, and `ink` carries white at 15.52:1 where
orange carries it at 3.05:1.

The same sweep moved the account page's destructive control off `red-700` /
`red-50` and onto the danger tokens, so its two grounds are worth stating: the
control is an outline, and its border stays drawn while the tint fills under the
pointer.

| pair | where | ratio |
|---|---|---|
| `#ffffff` on `--color-ink` `#1f2430` | dark pill label; selected tab label | 15.52 |
| `#ffffff` on `--color-code-chip` `#343b4a` | dark pill label, hover | 11.23 |
| `--color-ink` on `--color-surface-hover` `#f1ebe1` | nav and tab label, hover | 13.09 |
| `--color-danger` `#b8321c` as text on `--color-paper` | "Delete my account" heading | 5.65 |
| `--color-danger` as an edge on `--color-paper` | the destroy button's border | 5.65 |
| `--color-danger` as text on `--color-danger-tint` `#fbe3dc` | the destroy button's label, hover | 4.88 |
| `--color-danger-tint` against `--color-paper` | the destroy button's hover fill | 1.16 |

The last row is the alert's reasoning again: at 1.16:1 the tint cannot mark the
control by itself, and it does not have to — the border (5.65:1 on paper) and
the label (5.65:1, 4.88:1 while the tint is under it) carry it.
