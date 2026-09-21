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
