# The one button vocabulary, shared by the landing page and the signed-in
# screens. The class strings are docs/design/GUIDELINES.md section 3 verbatim;
# change them there and here together, never per screen.
#
#   <%= button_link t(".cta"), new_registration_path %>
#   <%= button_link t(".source"), repo_url, variant: :secondary %>
#   <%= button_to t(".remove"), account, method: :delete, class: button_classes(:destructive) %>
#   <%= button_submit form, t(".save") %>
#
# A class string, not a partial, so it drops into link_to, button_to and
# form builders alike and the <a> and the <button> share one definition.
# No focus styles here: the global two-tone ring in application.css covers
# every control (GUIDELINES rule 2.2).
module ButtonHelper
  RECIPES = {
    # The one primary action of a screen. Ink label on orange, never white.
    primary: {
      regular: "inline-flex items-center rounded-full bg-brand px-[26px] py-[15px] text-[16px] font-bold text-ink no-underline hover:bg-brand-hover",
      compact: "inline-flex items-center rounded-full bg-brand px-5 py-[11px] text-[15px] font-semibold text-ink no-underline hover:bg-brand-hover"
    },
    # A primary action where orange is already used on the screen.
    dark: {
      regular: "inline-flex items-center rounded-full bg-ink px-[26px] py-[15px] text-[16px] font-bold text-white no-underline hover:bg-code-chip",
      compact: "inline-flex items-center rounded-full bg-ink px-5 py-[11px] text-[15px] font-semibold text-white no-underline hover:bg-code-chip"
    },
    # The outline pill beside a CTA.
    secondary: {
      regular: "inline-flex items-center gap-2 rounded-full border-2 border-ink px-[26px] py-[15px] text-[16px] font-semibold text-ink no-underline hover:bg-surface-hover",
      compact: "inline-flex items-center gap-2 rounded-full border-2 border-ink px-[22px] py-[13px] text-[16px] font-semibold text-ink no-underline hover:bg-surface-hover"
    },
    # Removing a mailbox and anything else that cannot be undone. The label is
    # white, so hover darkens.
    destructive: {
      regular: "inline-flex items-center rounded-full bg-danger px-[26px] py-[15px] text-[16px] font-bold text-white no-underline hover:bg-danger-deep",
      compact: "inline-flex items-center rounded-full bg-danger px-5 py-[11px] text-[15px] font-semibold text-white no-underline hover:bg-danger-deep"
    },
    # Tertiary actions: no fill until hovered.
    ghost: {
      regular: "inline-flex items-center justify-center rounded-full px-4 py-2 text-[16px] font-semibold text-ink no-underline hover:bg-surface-hover",
      compact: "inline-flex items-center justify-center rounded-full px-4 py-2 text-[15px] font-semibold text-ink no-underline hover:bg-surface-hover"
    }
  }.freeze

  # A <button> shows the arrow cursor unless told otherwise; the 44px tap
  # target below lg is GUIDELINES rule 2.3 (the padded pills already clear it).
  SHARED = "cursor-pointer max-lg:min-h-11".freeze

  # On the brand-tint closing panel the outline pill hovers to surface, since
  # surface-hover barely differs from the tint.
  ON_TINT_HOVER = { "hover:bg-surface-hover" => "hover:bg-surface" }.freeze

  def button_classes(variant = :primary, size: :regular, on_tint: false)
    recipe = RECIPES.fetch(variant).fetch(size)
    recipe = recipe.gsub(/\S+/) { |klass| ON_TINT_HOVER.fetch(klass, klass) } if on_tint
    "#{recipe} #{SHARED}"
  end

  # link_to styled as a button. Takes link_to's arguments, including a block
  # for rich content; an extra class: is appended (layout only, e.g. "mt-4").
  def button_link(name = nil, options = nil, variant: :primary, size: :regular, on_tint: false, **html_options, &block)
    options, name = name, capture(&block) if block
    html_options[:class] = class_names(button_classes(variant, size:, on_tint:), html_options[:class])
    link_to(name, options, html_options)
  end

  # A form's submit button. Carries turbo_submits_with, so the submitting
  # state belongs to the component rather than to each form.
  def button_submit(form, label, variant: :primary, size: :regular, submitting: t("buttons.submitting"), **html_options)
    html_options[:class] = class_names(button_classes(variant, size:), html_options[:class])
    html_options[:data] = { turbo_submits_with: submitting }.merge(html_options[:data] || {})
    form.button(label, type: "submit", **html_options)
  end
end
