require "test_helper"

# The regression guard of the restyle story (task #12825), and the last thing
# that story adds: docs/design/GUIDELINES.md §6 bans the built-in Tailwind hues
# from every screen, because none of them was measured against our grounds. A
# `text-red-700` typed into a template renders plausibly enough that nothing
# else in this suite notices it — no other test looks at the colour of
# anything, and review sees a class among forty classes. So the guard fails on
# the class itself, where the mistake is made, rather than on the colour it
# happens to produce.
class DefaultPaletteTest < ActiveSupport::TestCase
  # What the guard reads. The helpers carry class strings of their own — the
  # recipes in ButtonHelper are the one place a pill may be written — so they
  # are scanned beside the templates they feed.
  SOURCES = %w[app/views/**/*.erb app/helpers/**/*.rb].freeze

  # Every hue Tailwind ships, not only the six §6 names by example: "or any
  # other built-in hue" is the rule, and a newly added utility family should
  # not need this list edited before it is caught. The trailing digit step is
  # what keeps the token families that share a name with a hue out of the
  # match — `bg-green`, `bg-green-tint` and `border-line` are ours, `green-500`
  # is not.
  HUES = %w[
    slate gray grey zinc neutral stone red orange amber yellow lime green
    emerald teal cyan sky blue indigo violet purple fuchsia pink rose
  ].freeze

  # A utility carrying a palette hue, with whatever variants lead up to it:
  # `bg-red-700`, `hover:bg-red-50`, `md:divide-gray-200`,
  # `aria-selected:text-blue-600`.
  PALETTE_CLASS = /
    \b
    (
      (?:[a-z-]+:)*          # variants
      ([a-z-]+?)             # the property: text, bg, border, divide, outline …
      -(?:#{HUES.join('|')})-\d+
    )
    \b
  /x

  # Where the token equivalent is, by the property the class sets. A pointer
  # into GUIDELINES §1, not a replacement for it.
  TOKENS = {
    "text" => "text-ink, text-ink-soft, text-ink-muted or text-danger",
    "bg" => "bg-paper, bg-surface, bg-surface-hover, bg-brand-tint or bg-danger-tint",
    "border" => "border-line, border-field-border, border-danger or border-ink",
    "divide" => "divide-line",
    "placeholder" => "placeholder:text-field-placeholder",
    "accent" => "accent-ink",
    # Not a colour choice at all: no screen may restyle focus (rule 2.2).
    "outline" => "nothing — the global two-tone ring is the only focus indicator",
    "ring" => "nothing — the global two-tone ring is the only focus indicator"
  }.freeze
  ELSEWHERE = "docs/design/GUIDELINES.md §1 lists the whole palette".freeze

  test "no view or helper uses a built-in Tailwind palette class" do
    offenders = palette_classes

    assert_empty offenders, <<~MESSAGE
      The built-in Tailwind palette is banned: those hues are not our colours
      and were never measured against our grounds (docs/design/GUIDELINES.md
      §6). #{offenders.size} to replace:

      #{offenders.join("\n")}
    MESSAGE
  end

  private
    def palette_classes
      SOURCES.flat_map { |glob| Dir[Rails.root.join(glob)] }.sort.flat_map do |file|
        File.readlines(file).each_with_index.flat_map do |line, index|
          line.scan(PALETTE_CLASS).uniq.map do |klass, property|
            "#{file.delete_prefix("#{Rails.root}/")}:#{index + 1} — #{klass} → #{TOKENS.fetch(property, ELSEWHERE)}"
          end
        end
      end
    end
end
