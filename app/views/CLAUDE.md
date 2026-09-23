# app/views

How a screen is built here. Compose the shared pieces below; do not invent new ones inline.

## The two layouts

- `layouts/public.html.erb`: the marketing pages (`PagesController`, `GuidesController`) and the hitch-rails screens (`config/initializers/hitch.rb` sets `Hitch::ApplicationController.layout "public"`). Renders `shared/marketing_header` and `shared/marketing_footer`.
- `layouts/application.html.erb`: everything signed in. Renders `shared/app_header`, no footer.

Both carry the skip link (first in the tab order, targets `#main`), the `landing-shell` column and `shared/flash` inside `<main id="main">`. A view yields into that column; it does not open its own page shell, and it does not render the flash again.

## The partial vocabulary

A new screen composes these. A new inline button, alert box or form field is a bug.

| Piece | For |
| --- | --- |
| `shared/_app_header` | Signed-in nav (owned by the layout) |
| `shared/_marketing_header`, `shared/_marketing_footer` | Public nav and footer (owned by the layout) |
| `shared/_page_header` | Top of a signed-in screen: `title:`, optional `lede:`, a block for the action slot |
| `shared/_field` | One form control with label, hint and inline error |
| `shared/_error_summary` | Validation list for a model (`model:`); renders `#errors` |
| `shared/_flash` | Per-request `notice` / `alert` (owned by the layout) |
| `shared/_alert` | In-page callout, `variant:` `:info`, `:warning` or `:danger` |
| `shared/_badge` | Status pill, `variant:` `:ok`, `:denied` or `:neutral` (counters) |
| `shared/_locale_switcher` | Language switch; header and footer render it |

Buttons are not a partial. `ButtonHelper` (`app/helpers/button_helper.rb`) gives `button_link`, `button_submit` and `button_classes(:variant)` for `link_to` / `button_to`. A status pill is `shared/_badge`, not an inline class string. Each partial documents its own locals in the comment at its top.

## Tokens

The palette is the `@theme` block in `app/assets/tailwind/application.css`: no default Tailwind palette classes, no inline hex. `test/views/default_palette_test.rb` scans this directory and `app/helpers` for a built-in hue and fails on the class, naming the token to use instead, so a stray `text-red-700` is caught at review time rather than shipped. Everything else (recipes, type scale, hard rules, copy, extending the system) is in `docs/design/GUIDELINES.md`; read it before touching markup.

## DOM ids the tests hold on to

`#empty` `#errors` `#connection-error` `#no-mailbox` `#alert` `#notice` `#server-url` `#language-switcher`

Changing the markup around them is fine; renaming or dropping them breaks the suite. Keep the id on an element of the same meaning. The full table and the brittle structural selectors (first `<section>` in `<main>` is the landing hero, the `<details>` "Recent activity" summary, the sessions placeholders) are in GUIDELINES section 8.

## Localization

Every user-facing string comes from a locale file, in both `cs` and `en` (`config/locales/`), with no exceptions, including `aria-label`s and button text. Lazy lookup (`t(".key")`) resolves against the view's own path, so inside a partial it must not be called from a block yielded from another view. Czech copy runs longer than English: check every new layout with it, especially on a phone width, since that is where layouts break.

## Stimulus

Behaviour comes from Stimulus controllers in `app/javascript/controllers`: `clipboard`, `tabs`, `auto_submit`. If a restyle moves markup, check the controller's `data-*-target` and value attributes still sit inside the element carrying `data-controller`.
