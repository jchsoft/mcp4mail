require "application_system_test_case"

# The one system test that lets the hero mock play: the rest of the suite asks
# the browser for reduced motion and sees the finished conversation.
class HeroDemoTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_firefox, screen_size: [1400, 1400] do |options|
    options.add_preference("intl.accept_languages", "en")
  end

  test "the hero mock rewinds on connect and plays through to the server-rendered answer" do
    visit root_url

    within "figure[data-controller=hero-demo]" do
      # Rewound: every piece still to come keeps its box, so the hero does not
      # move while the sequence fills it in.
      assert_selector "[data-hero-demo-target=answer].hero-demo-pending", visible: :all
      height = figure_height

      assert_selector "[data-hero-demo-target=composer]", text: "What did my insurer", wait: 5
      assert_selector "[data-hero-demo-target=spinner]:not(.hidden)", visible: :all, wait: 10
      assert_no_selector ".hero-demo-pending", visible: :all, wait: 15

      assert_no_selector "[data-hero-demo-target=check].hidden", visible: :all
      assert_selector "[data-hero-demo-target=composer]", text: "Ask about your mail…"
      assert_text "Read from your mailbox · 4 messages"
      assert_equal height, figure_height
    end
  end

  private
    def figure_height
      evaluate_script("document.querySelector('figure[data-controller=hero-demo]').offsetHeight")
    end
end
