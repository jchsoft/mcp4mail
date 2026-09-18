# Landing page design reference

`landing-v2.html` is the **approved v2 landing design** for mcp4mail — the source of
truth for the rebuild of the public landing page ([story #12693]). It is a vendored,
dependency-free copy of the Design Compiler prototype `mcp4mail Landing v2.dc.html`
(sha256 `9be2a9909405267b8bf27bfbc8da59e10fbb5f95e78002d41b6e5c1a24022a68`): the
prototype runtime was stripped and the `style-hover="…"` attributes were converted
into real CSS `:hover` rules, but the markup, copy, colours and spacing are unchanged.
Open it straight from the filesystem in a browser — it needs no build step and no
server. It holds **both** language blocks in full (`<section lang="cs">` then
`<section lang="en">`), so the Czech and English copy both come from here; the
prototype's CS/EN switcher is inert in this static copy, which is why both blocks
render one after the other. Sections carry `data-screen-label` attributes — that is
how the sibling subtasks address them.

## Design tokens

### Colors

| Token | Value |
| --- | --- |
| Page background (cream) | `#fbf8f3` |
| Primary text (near-black navy) | `#1f2430` |
| Secondary text | `#4a515f` |
| Muted text | `#6b7280` |
| Primary CTA (orange) | `#f26b1d` |
| Primary CTA hover | `#e35f14` |
| CTA label text | `#1f2430` (not white) |
| Links / green accent | `#1f8a70` |
| Link hover, dark-on-light green | `#15654f` |
| Green tint | `#dff3ec` |
| Highlight yellow (H1 underline, kickers, links in the dark block) | `#ffd166` |
| Surface white | `#fff` |
| Warm hover surface | `#f1ebe1` |
| Warm border | `#ebe4d8` |
| Orange tint | `#fde9dc` |
| Dark panel | `#1f2430` |
| Dark panel body text | `#cfd3dc` |
| Inline-code chip (on dark) | `#343b4a` |

### Type

| Role | Value |
| --- | --- |
| Headings | Bricolage Grotesque, weights 500/700/800, tracking -0.02 to -0.03em |
| Body | Instrument Sans, weights 400/500/600 + italic 400 |
| Inline code | `ui-monospace, monospace` |
| H1 | `clamp(42px, 5.6vw, 72px)` |
| Section H2 | `clamp(30px, 3.6vw, 46px)` |
| Secondary H2 | `clamp(28px, 3.4vw, 42px)` |

Both families are loaded from Google Fonts by the `<link>` in the file's `<head>`.

### Radii

| Role | Value |
| --- | --- |
| Pills, buttons, chips | `999px` |
| Dark panel | `32px` |
| Cards | `24px` / `20px` / `16px` |
| Small elements | `10px` / `6px` |
| Chat bubble — question (right) | `22px 22px 6px 22px` |
| Chat bubble — answer (left) | `22px 22px 22px 6px` |

### Spacing and other

| Role | Value |
| --- | --- |
| Content column max-width | `1160px` |
| Page padding | `clamp(20px, 5vw, 48px)` |
| Focus ring | `3px solid #f26b1d`, offset `3px`, radius `6px` — never the browser default |
| `::selection` background | `#ffd166` |
| Scroll behaviour | `html { scroll-behavior: smooth }` |

## The rejected variant

The original design archive also held a serif **"Broadsheet"** newspaper variant with
its own `_ds/` design-system folder. **It was rejected and must not be used** — nothing
from it is in scope, and it is deliberately not vendored here. Only v2 is approved.

## What was changed when vendoring

The conversion was mechanical apart from the hover states. For the record:

- Dropped the prototype runtime: `support.js`, the `<x-dc>` wrapper, the trailing
  `<script type="text/x-dc">` component class and its `data-dc-script` block.
- Hoisted the `<helmet>` contents into a real `<head>`.
- `<sc-if value="{{ isCs }}">` / `{{ isEn }}` became `<section lang="cs">` /
  `<section lang="en">`; the `onClick="{{ setCs }}"` / `{{ setEn }}` language links
  became plain `href="#"`.
- The two `<image-slot>` elements became plain `<img>` tags on the local
  `placeholder-live.svg`; `image-slot.js` is gone. The real screenshot asset now
  lives at `app/assets/images/mcptask-live.webp` and is rendered by
  `app/views/pages/_built_live_image.html.erb`; the capture recipe is in task #12697.
  The placeholder stays here so this reference page keeps rendering on its own.
- The 24 `style-hover="…"` attributes became six generated `.hv-N:hover` rules in a
  `<style>` block, one per distinct declaration. They are marked `!important`: the
  design styles every element with an inline `style="…"`, which would otherwise win on
  specificity and leave the hover states doing nothing. The prototype runtime swapped
  inline styles directly, so the question never came up there.

[story #12693]: https://mcptask.online/jchsoft/pieces/12693

## The Open Graph card

`og-image.html` is the source of `public/og-image.png` — the 1200×630 card link
previews show. It is the same kind of file as `landing-v2.html`: plain HTML with no
build step, openable straight from the filesystem. It sets the hero line in the repo's
own self-hosted Bricolage Grotesque (referenced relatively out of
`app/assets/fonts/`), so the card and the page it previews are set in the same type.

The body is exactly 1200×630 with no margin. Render it with the Chrome that
`selenium-webdriver` already downloaded — screenshot a **taller** window and crop the
top 1200×630, because a window sized exactly to the content clips the last element:

```sh
CHROME="$HOME/.cache/selenium/chrome/mac-arm64/$(ls -1 "$HOME/.cache/selenium/chrome/mac-arm64" | tail -1)/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
"$CHROME" --headless --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --force-device-scale-factor=1 --window-size=1200,900 \
  --screenshot=/tmp/og.png "file://$PWD/docs/design/og-image.html"
magick /tmp/og.png -crop 1200x630+0+0 +repage \
  -background '#fbf8f3' -alpha remove -alpha off -strip public/og-image.png
```

The `-alpha remove` keeps the file opaque: a transparent PNG goes black behind the
dark-mode preview panes of some chat clients.

## The favicon set

`public/icon.svg` is the source of the other three icons — the envelope of the first
branded set, recoloured to the v2 pair (orange `#f26b1d` ground, ink `#1f2430`
strokes). Regenerate them from it:

```sh
rsvg-convert -w 512 -h 512 public/icon.svg -o public/icon.png
rsvg-convert -w 180 -h 180 public/icon.svg -o /tmp/apple.png
magick /tmp/apple.png -background '#f26b1d' -alpha remove -alpha off public/apple-touch-icon.png
for s in 16 32 48; do rsvg-convert -w $s -h $s public/icon.svg -o /tmp/ico-$s.png; done
magick /tmp/ico-16.png /tmp/ico-32.png /tmp/ico-48.png public/favicon.ico
```

`apple-touch-icon.png` is flattened onto the orange because iOS composites it over
white and would otherwise show a white ring inside the rounded mask.
