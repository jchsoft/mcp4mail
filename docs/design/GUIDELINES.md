# UI guidelines

The rulebook for every screen of mcp4mail. [README.md](README.md) records the v2
landing design as it was drawn; this file says how the shipped system is used, and
every UI change is reviewed against it. Where the two disagree, this file and
`app/assets/tailwind/application.css` win.

Every rule below carries its reason. A rule without one looks arbitrary and gets
"improved" away; if a reason stops being true, change the rule and the reason
together.

## 1. The palette is the `@theme` block, and nothing else

The only colours, families and heading sizes in the product are the tokens of the
`@theme static` block in `app/assets/tailwind/application.css`. `static` makes
Tailwind emit every token even before a view uses it, so any utility below works
in any template.

### Colours

| Token | Value | Utility | What it is for |
| --- | --- | --- | --- |
| `--color-paper` | `#fbf8f3` | `bg-paper` | The page ground (set on `body`), and the light fill inside a surface: chat bubbles, the fake URL bar. |
| `--color-ink` | `#1f2430` | `text-ink`, `bg-ink`, `border-ink` | Primary text; the label on every orange CTA; the dark panel and dark pill; the outline pill's border. |
| `--color-ink-soft` | `#4a515f` | `text-ink-soft` | Body copy and secondary text — ledes, answers, card descriptions. 7.5:1 on paper. |
| `--color-ink-muted` | `#5c626e` | `text-ink-muted` | Small print: notes, disclaimers, the footer, labels at 13–14px. Never for body copy. |
| `--color-ink-on-dark` | `#cfd3dc` | `text-ink-on-dark` | Body text on the dark panel (`bg-ink`). 10.4:1. |
| `--color-code-chip` | `#343b4a` | `bg-code-chip`, `hover:bg-code-chip` | Inline code on the dark panel; the hover state of the dark pill. |
| `--color-brand` | `#f26b1d` | `bg-brand`, `border-brand` | The primary CTA fill, the wordmark tile, the first step numeral, the alert border. Never text. |
| `--color-brand-hover` | `#f5792f` | `hover:bg-brand-hover` | Hover on an orange CTA. It is lighter than `brand` on purpose (see rule 2.5). |
| `--color-brand-deep` | `#bc430f` | `text-brand-deep` | Orange as text on light grounds: kickers, the nav hover, the alert text, the FAQ mark. |
| `--color-brand-tint` | `#fde9dc` | `bg-brand-tint` | Soft orange ground: the closing CTA panel, the alert, chips, the FAQ mark disc. |
| `--color-green` | `#1a7a63` | `bg-green`, `text-green` | Links on paper; the "watch it live" pill (white label); the third step numeral. Light grounds only. |
| `--color-green-deep` | `#15654f` | `text-green-deep`, `hover:bg-green-deep`, `hover:text-green-deep` | Link hover; green text on `green-tint` (badges, the notice). |
| `--color-green-tint` | `#dff3ec` | `bg-green-tint` | Soft green ground: the hero badge, status chips, the notice. |
| `--color-highlight` | `#ffd166` | `bg-highlight`, `text-highlight` | The marker under the hero word, `::selection`, and the accent colour on the dark panel (kickers, links, the dot). |
| `--color-surface` | `#ffffff` | `bg-surface` | Cards, disclosures, the tab strip, any raised box on paper. |
| `--color-surface-hover` | `#f1ebe1` | `hover:bg-surface-hover`, `bg-surface-hover` | Hover for outline pills, tabs and card links; the ground of inline code on light; the language switch track. |
| `--color-line` | `#ebe4d8` | `border-line` | Every hairline border: cards, disclosures, table rows. |
| `--color-danger` | `#b8321c` | `text-danger`, `bg-danger`, `border-danger` | Errors and destructive actions: error text, the destructive button (white label), the error alert border. A brick red in the brand family. 5.65:1 on paper. |
| `--color-danger-deep` | `#8f2613` | `hover:bg-danger-deep`, `text-danger-deep` | Hover on a destructive button (it darkens: the label is white); danger text on `danger-tint`. |
| `--color-danger-tint` | `#fbe3dc` | `bg-danger-tint` | Soft red ground: the error alert and error summary. Always with a `danger` border. |
| `--color-field-border` | `#8a8378` | `border-field-border` | The border of every input, select and textarea. 3:1 on paper and surface, unlike `line`. |
| `--color-field-placeholder` | `#6f6a63` | `placeholder:text-field-placeholder` | Placeholder text in form fields. |

### Families

| Token | Utility | What it is for |
| --- | --- | --- |
| `--font-heading` (Bricolage Grotesque, 500–800) | `font-heading` | Headings and heading-like display text (see section 4). |
| `--font-body` (Instrument Sans, 400–600 + italic 400) | `font-body` | Everything else. It is the `body` default, so you almost never write it. |
| `--font-code` (`ui-monospace, monospace`) | `font-code` | Inline code, the MCP server URL, anything the user copies verbatim. |

Both families are self-hosted from `app/assets/fonts`; never add a Google Fonts
link (`tailwind_theme_test.rb` refuses one).

### Heading sizes

| Token | Value | Utility | What it is for |
| --- | --- | --- | --- |
| `--text-h1` | `clamp(42px, 5.6vw, 72px)`, lh 1.02, -0.03em | `text-h1` | The one landing hero `h1`. |
| `--text-h2` | `clamp(30px, 3.6vw, 46px)`, lh 1.08, -0.025em | `text-h2` | Landing section headings. |
| `--text-h2-sub` | `clamp(28px, 3.4vw, 42px)`, lh 1.1, -0.02em | `text-h2-sub` | Secondary section headings (the "Built on it" and closing blocks). |

The line height and tracking travel with the size, so `text-h1` needs no
`leading-*` or `tracking-*` beside it.

## 2. Hard rules

1. **The CTA label is ink on orange, never white.** `text-ink` on `bg-brand` is
   5.10:1; `text-white` on `bg-brand` is 3.05:1, under the 4.5:1 AA asks of button
   text. Every orange button is `bg-brand text-ink`, however "brand-like" white
   looks in a mock-up. (`connect_ai/show.html.erb`'s Copy button breaks this today
   and is being fixed by its own task.)

2. **The focus indicator is the global two-tone ring, and only that.** The
   `*:focus-visible` rule in the `@layer base` block of `application.css` draws a
   3px ink outline over a 6px orange box-shadow. No single colour carries across
   this product: orange alone is 2.87:1 on paper, 2.59:1 on `brand-tint` and 1.72:1
   on the green pill, under the 3:1 WCAG 1.4.11 asks; ink alone vanishes on the dark
   panel. Two tones cover both. So no component sets `focus:outline-*`,
   `focus:ring-*`, `focus-visible:*` or `outline-none`: any local override replaces
   a ring that works everywhere with one that fails somewhere. The one exception
   is already in the base layer — `main[tabindex="-1"]`, the skip link's target,
   which is not a control.

3. **Tap targets are at least 44px below `lg`.** Every link or button that is not
   already a padded pill carries `max-lg:min-h-11` (and `max-lg:min-w-11` when it is
   an icon or a single glyph, as the header's language links are). 44px is the
   WCAG 2.5.5 target size; above `lg` the pointer is a mouse and the design's
   tighter rhythm is kept.

4. **Green is banned on the dark panel.** `green` on `ink` is 2.96:1 and
   `green-deep` is 2.22:1 — neither passes as text or as a non-text indicator. On
   `bg-ink` the accent is `highlight` (10.76:1): kickers, links and status dots.

5. **Four tokens were moved on purpose; never "restore" the README hexes.**
   `ink-muted` (`#6b7280` → `#5c626e`), `brand-hover` (`#e35f14` → `#f5792f`),
   `brand-deep` (`#c94a12` → `#bc430f`) and `green` (`#1f8a70` → `#1a7a63`) differ
   from the table in [README.md](README.md) because the design's values failed or
   grazed AA in the places they are used; the comments in `@theme` and the table in
   [axe-report.md](../accessibility/axe-report.md) give each measurement.
   `test/assets/tailwind_theme_test.rb` pins the shipped values, so "fixing" one
   back to the README fails CI. `brand-hover` is the counter-intuitive one: the
   label is ink, so a darker orange would cost contrast — hover lightens.

## 3. Component recipes

Copy these class strings; do not re-derive them. They are the landing page's own
(`app/views/pages/`, `shared/_marketing_header.html.erb`), and a screen that needs
something they do not cover is a sign to extend this list, not to improvise.

**Buttons come from `ButtonHelper`** (`app/helpers/button_helper.rb`), which
carries the pill recipes below plus `max-lg:min-h-11` and `cursor-pointer`:
`button_link` for an `<a>`, `button_classes(variant)` for `button_to`, and
`button_submit form, label` for a form, which adds `turbo_submits_with`.
Variants: `:primary`, `:dark`, `:secondary`, `:destructive`, `:ghost`; sizes
`:regular` and `:compact`; `on_tint: true` for the brand-tint panel. Never paste a
pill's class string into a view; change the recipe here and in the helper together.

**Orange pill CTA** — the one primary action of a screen. Ink label (rule 2.1).

```
inline-flex items-center rounded-full bg-brand px-[26px] py-[15px] text-[16px] font-bold text-ink no-underline hover:bg-brand-hover
```

**Outline pill** — the secondary action beside a CTA. On the `brand-tint`
closing panel hover to `hover:bg-surface` instead.

```
inline-flex items-center gap-2 rounded-full border-2 border-ink px-[26px] py-[15px] text-[16px] font-semibold text-ink no-underline hover:bg-surface-hover
```

**Dark pill** — a primary action where orange has already been used on the
screen (the header's sign-up, the closing CTA), so the page does not ask twice in
the same colour.

```
inline-flex items-center rounded-full bg-ink px-[26px] py-[15px] text-[16px] font-bold text-white no-underline hover:bg-code-chip
```

Compact size, for the header and inline use: `px-5 py-[11px] text-[15px] font-semibold`
(dark pill) or `px-[22px] py-[13px]` (outline pill), everything else unchanged.

**Card** — any raised box of content on paper.

```
rounded-[20px] border border-line bg-surface p-6
```

A card that is itself a link adds `text-ink no-underline hover:bg-surface-hover`.

**Kicker** — the small uppercase label above a section heading. Body font, not
`font-heading`. On the dark panel swap `text-brand-deep` for `text-highlight`.

```
block text-sm font-bold tracking-[.04em] text-brand-deep uppercase
```

**Chip** — a short status or tag. Green for a state that is good or live, orange
tint for a neutral label.

```
inline-flex items-center gap-2 rounded-full bg-green-tint px-3.5 py-1.5 text-[13px] font-semibold text-green-deep
inline-flex items-center rounded-full bg-brand-tint px-3.5 py-1.5 font-semibold text-ink
```

**Code chip** — inline code inside running text, set on the paragraph so the
translated copy can carry plain `<code>` tags. On the dark panel replace
`bg-surface-hover` with `bg-code-chip`. Add `[&_code]:[overflow-wrap:anywhere]`
wherever the code is a URL or a hostname, so it cannot push a phone layout sideways.

```
[&_code]:rounded-md [&_code]:bg-surface-hover [&_code]:px-2 [&_code]:py-0.5 [&_code]:font-code [&_code]:text-sm [&_code]:text-ink
```

**Disclosure** — native `<details>`/`<summary>`, no Stimulus: the browser already
supplies keyboard handling and the expanded state. The base layer hides the
default marker and rotates `.faq-mark` from + to × on open, with one
reduced-motion opt-out; the span must keep the `faq-mark` class and
`aria-hidden="true"`.

```erb
<details class="rounded-2xl border border-line bg-surface px-[22px] py-[18px]">
  <summary class="flex cursor-pointer items-center gap-3.5 font-heading text-[19px] font-bold max-lg:min-h-11">
    <span aria-hidden="true" class="faq-mark inline-flex size-[26px] flex-none items-center justify-center rounded-full bg-brand-tint text-[18px] text-brand-deep">+</span>
    Question
  </summary>
  <p class="mt-3 ml-10 text-base leading-[1.6] text-ink-soft">Answer</p>
</details>
```

**Tabs** — the `tabs` Stimulus controller over a real `role="tablist"`
(`connect_ai/show.html.erb`). The strip and a tab:

```
flex flex-wrap gap-1 rounded-xl border border-line bg-surface p-1
grow cursor-pointer rounded-lg px-4 py-2 text-sm font-semibold text-ink-soft hover:bg-surface-hover aria-selected:bg-ink aria-selected:text-white aria-selected:hover:bg-ink
```

The selected state is driven by `aria-selected`, never by a separate class, so
what the eye sees and what a screen reader hears cannot drift apart.

**Flash and alert** — two partials, not class strings. `shared/_flash` is the
per-request message: `#alert` on the danger tokens with `role="alert"`, `#notice`
on the green tint with `role="status"`, both live regions so a Turbo navigation
is announced. `shared/_alert` is the in-page callout that belongs to a section:
`render "shared/alert", variant:, id:, class:, title:, body:` with variants
`:info` (surface and line: guidance), `:warning` (brand tint) and `:danger`
(danger tokens, `role="alert"`). Content comes in as `title:`/`body:` rather than
a block, so the caller's relative `t(".key")` keeps its own scope.

**Badge** — `shared/_badge`, not a class string: a status pill carrying one word
or one number beside the thing it describes. `render "shared/badge", variant:,
label:, id:, class:` with variants `:ok` (green: the call did what was asked),
`:denied` (danger: refused or failed) and `:neutral` (a fact with no verdict — a
counter, a limit that was hit). Smaller than a chip, because it sits inside a
dense list rather than beside a heading; border plus fill in one family, as
`shared/_alert` has, so the three variants are one box in three colours. The
colour repeats what the label says, so the badge is never the only carrier of
the meaning and needs no `aria-label` of its own.

```
inline-flex items-center rounded-full border px-2.5 py-0.5 text-[13px] font-semibold
border-green bg-green-tint text-green-deep
border-danger bg-danger-tint text-danger-deep
border-line bg-surface-hover text-ink-soft
```

**Text link** — `text-green hover:text-green-deep` with an underline in running
text on paper; `text-highlight` on the dark panel (rule 2.4).

## 4. Layout and type

**The column.** Every page body sits in `landing-shell`: `max-width: 1160px`,
centred, `padding-inline: clamp(20px, 5vw, 48px)`. Header, sections and footer
share it, so their edges line up. Narrower reading measures (FAQ, guides, forms)
go inside it with a `max-w-[…]`, never by changing the shell.

**When `font-heading` applies.** Headings (`h1`–`h3`) and text that plays a
heading's role: the disclosure summary, a card's quote, the wordmark, the step
numerals. Always at `font-bold` or `font-extrabold` — the family is loaded from
500 up, and it reads as a heading only when heavy. It does **not** apply to body
copy, buttons, form labels and inputs, table text or kickers: those are
Instrument Sans, and a button in Bricolage reads as a headline, not as a control.

**The heading scale.**

| Level | Classes |
| --- | --- |
| Landing hero `h1` | `font-heading text-h1 font-extrabold` |
| Section `h2` | `font-heading text-h2 font-extrabold` (secondary: `text-h2-sub`) |
| Internal page `h1` | `font-heading text-4xl font-extrabold tracking-[-0.02em]` |
| `h3`, card title | `font-heading text-2xl font-bold tracking-[-0.015em]` (in a dense list: `text-[20px]`) |

The fluid `text-h*` sizes belong to the marketing pages; a signed-in screen's
`h1` is the fixed `text-4xl`, because a form does not need a 72px headline.

**Radius scale.** These are the only radii in use; pick the nearest one, and do
not invent a new value.

| Radius | Utility | Used for |
| --- | --- | --- |
| 999px | `rounded-full` | Pills, buttons, chips, avatars, dots |
| 32px | `rounded-[32px]` | Full-width panels: the dark Security panel, the closing CTA |
| 24px | `rounded-[24px]` / `rounded-3xl` | Large media frames (the hero chat, the live screenshot) |
| 22px | `rounded-[22px]` | The guide cards and guide CTA panel |
| 20px | `rounded-[20px]` | Cards |
| 16px | `rounded-2xl` | Disclosures, the URL box, step numerals |
| 12px | `rounded-xl` | The tab strip, the flash messages |
| 10px | `rounded-[10px]` | The wordmark tile |
| 8px | `rounded-lg` | A tab, small inline notes |
| 6px | `rounded-md` | Inline code chips |

The chat bubbles' asymmetric corners (`rounded-[20px_20px_6px_20px]` and its
mirror, `rounded-[16px_16px_4px_16px]` in the compact history) are part of the
chat mock and stay there.

**Shadow scale.** One shadow exists: `shadow-[0_12px_40px_rgba(31,36,48,.08)]`,
for a media frame lifted off the page (the hero chat, the live screenshot).
Cards are flat and separated by `border-line`, not by a shadow. The `shadow-sm` on
today's form inputs is Tailwind's default and goes with the restyle of those forms.

## 5. Copy rules

Every string goes through I18n and exists in both `cs` and `en`.

- **Sentence case** everywhere — headings, buttons, tabs, labels. "Connect a
  mailbox", not "Connect A Mailbox". Czech is sentence case by nature; English
  must match it.
- **Buttons are active verbs naming what happens**: "Connect mailbox", "Copy
  address", "Remove mailbox". Never "OK", "Submit" or "Continue", which say nothing
  about the result.
- **One verb through a whole flow.** A "Remove" button asks "Remove this
  mailbox?" and ends in "Mailbox removed" — not "Delete" in the dialog and
  "Disconnected" in the notice. A changed verb makes the user wonder whether a
  different thing happened.
- **Errors say what went wrong and what to do about it.** "The server refused the
  password. Check that you used an app password, not your login password." — not
  "Authentication failed".
- **An empty screen invites an action**, it does not report emptiness. "Connect
  your first mailbox to let your AI read it", with the button beside it — not
  "You have no mailboxes".

## 6. Never

- No default Tailwind palette classes: `gray-*`, `blue-*`, `red-*`, `slate-*`,
  `zinc-*`, `neutral-*` (or any other built-in hue). They are not our colours and
  were never measured against our grounds. `test/views/default_palette_test.rb`
  reads every view and helper for one and fails on the class, with the token to
  use instead in the message.
- No inline hex, `rgb()` or `style="color: …"` in a view. If the colour is not a
  token, it is not in the design.
- No per-component focus styles (`focus:outline-*`, `focus:ring-*`,
  `outline-none`) — rule 2.2.
- No new radius or shadow values outside the scales in section 4.
- No white label on `bg-brand` (rule 2.1) and no green on `bg-ink` (rule 2.4).
- No `tailwind.config.js`. Tailwind v4 is configured in CSS.

## 7. Extending the system

When a screen truly needs something the tokens do not have (a danger colour, a
form-field border), add it — in this order, all in the same pull request:

1. **Add the token to `@theme`** in `app/assets/tailwind/application.css`, with a
   comment saying what it is for and, if it carries text, the ratio it was chosen
   for.
2. **Pin it in `test/assets/tailwind_theme_test.rb`** (`REQUIRED_COLORS`, or the
   heading-size map), so a later edit cannot drift it silently.
3. **Record the measured contrast pair** — the token against every ground it
   appears on — in the table in
   [docs/accessibility/axe-report.md](../accessibility/axe-report.md).

Then add its row to section 1 here, and a recipe to section 3 if it introduces a
new component.

## 8. What the tests hold on to

A restyle may change every class around these, but not these. The system and
controller tests find the page through them; renaming one turns a visual change
into a red suite.

**DOM ids** — keep the id on an element of the same meaning:

| Id | Where |
| --- | --- |
| `#empty` | `mail_accounts/index` — the no-mailbox state |
| `#errors` | the validation list on `mail_accounts/new` and `registrations/new` |
| `#connection-error` | `mail_accounts/new` — the IMAP connection failure |
| `#no-mailbox` | `connect_ai/show` — shown when no mailbox is connected |
| `#alert`, `#notice` | `shared/_flash` |
| `#server-url` | `connect_ai/show` — the readonly MCP URL input |
| `#language-switcher` | the signed-in nav |

**Structural selectors** (story 12795):

- `main section:first-of-type` — the landing hero is the first `<section>` in
  `<main>` (`home_test.rb`, `onboarding_test.rb`, `landing_responsive_test.rb`).
  Do not put another section, or wrap the hero, ahead of it.
- `find("summary", text: "Recent activity")` and the `li` assertions in
  `mailbox_activity_test.rb` — the per-mailbox activity on `mail_accounts/index`
  stays a `<details>` whose `<summary>` reads "Recent activity", with one `<li>`
  per entry.
- The placeholder-based `fill_in placeholder: "Enter your email address"` /
  `"Enter your password"` on `sessions/new` in `design_tokens_test.rb` — keep those
  placeholders (and their I18n keys) even when visible labels are added.
