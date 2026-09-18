require "test_helper"

# The landing copy lives in cs.yml and en.yml in one shape, so a section view can
# iterate the same keys in either locale. These guard that shape.
class LocaleParityTest < ActiveSupport::TestCase
  test "the pages namespace has the same keys in every locale" do
    paths = I18n.available_locales.index_with { |locale| key_paths(pages_for(locale)) }
    every_key = paths.values.reduce(:|).sort

    paths.each do |locale, keys|
      assert_equal [], every_key - keys,
        "config/locales/#{locale}.yml is missing keys that the other locale files define"
    end
  end

  test "pages.home resolves in every locale" do
    I18n.available_locales.each do |locale|
      assert_nothing_raised { I18n.t("pages.home", locale: locale, raise: true) }
    end
  end

  test "only _html keys carry markup" do
    I18n.available_locales.each do |locale|
      with_markup = leaves(pages_for(locale)).select { |_path, value| value.include?("<") }

      with_markup.each do |path, value|
        assert path.end_with?("_html"), "#{locale}.yml: #{path} contains markup (#{value}) but is not an _html key"
      end
    end
  end

  test "interpolations are the same in every locale" do
    placeholders = I18n.available_locales.index_with do |locale|
      leaves(pages_for(locale)).to_h { |path, value| [ path, value.scan(/%\{\w+\}/).sort ] }
    end

    reference_locale, reference = placeholders.first
    placeholders.except(reference_locale).each do |locale, found|
      assert_equal reference, found,
        "config/locales/#{locale}.yml interpolates different variables than #{reference_locale}.yml"
    end
  end

  private
    def pages_for(locale)
      YAML.load_file(Rails.root.join("config/locales/#{locale}.yml")).fetch(locale.to_s).fetch("pages")
    end

    def key_paths(node)
      leaves(node).map(&:first)
    end

    # [ [ "home.hero.badge", "Open source…" ], … ]
    def leaves(node, prefix = "")
      case node
      when Hash  then node.flat_map { |key, value| leaves(value, "#{prefix}#{key}.") }
      when Array then node.each_with_index.flat_map { |value, index| leaves(value, "#{prefix}#{index}.") }
      else [ [ prefix.chomp("."), node.to_s ] ]
      end
    end
end
