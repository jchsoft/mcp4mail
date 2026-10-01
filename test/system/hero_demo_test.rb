require "application_system_test_case"

# The one system test that lets the hero mock play: the rest of the suite asks
# the browser for reduced motion and sees the finished conversation.
class HeroDemoTest < ApplicationSystemTestCase
  driven_with_motion

  # The narrow tests shrink the window, and the next test in this browser would
  # open the page with the figure below the fold, where it never plays.
  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

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

  # The stacked hero: below ~830px the mock sits under the copy, and on a 375px
  # phone the Czech question and bullets wrap the most. Sampled on every frame
  # of the sequence, the figure must keep one height and the page must never
  # scroll sideways. The frame trick is the one landing_responsive_test.rb
  # explains: headless Firefox will not open a window that narrow.
  [[375, :cs], [375, :en], [820, :cs]].each do |width, locale|
    test "the hero mock plays without shifting or overflowing at #{width}px in #{locale}" do
      open_frame(width, locale)

      within_frame(find("#viewport")) do
        figure = find("figure[data-controller=hero-demo]")
        assert_selector "[data-hero-demo-target=answer].hero-demo-pending", visible: :all
        execute_script(<<~JS)
          window.heroSamples = [];
          const figure = document.querySelector("figure[data-controller=hero-demo]");
          const root = document.documentElement;
          (function sample() {
            window.heroSamples.push([figure.offsetHeight, root.scrollWidth - root.clientWidth]);
            requestAnimationFrame(sample);
          })();
        JS
        scroll_to figure, align: :center

        # On a phone the figure may already be in view when the frame loads, so
        # the sequence can be past any one beat by now; the sampler started
        # while pieces were still pending, which is what the check needs.
        assert_no_selector ".hero-demo-pending", visible: :all, wait: 20

        heights, overflows = evaluate_script("window.heroSamples").transpose
        assert_operator heights.size, :>, 100, "the sampler barely ran"
        assert_equal [heights.first], heights.uniq, "#{locale} at #{width}px: the figure changed height mid-sequence"
        assert_operator overflows.max, :<=, 0, "#{locale} at #{width}px: the page scrolled sideways mid-sequence"
      end
    end
  end

  private
    def open_frame(width, locale)
      page.driver.browser.manage.window.resize_to([width + 80, 560].max, 1000)
      visit root_url(locale: locale)

      page.execute_script(<<~JS, root_url(locale: locale), width)
        const [url, width] = arguments;
        document.body.replaceChildren();
        document.body.style.margin = "0";
        const frame = document.createElement("iframe");
        frame.id = "viewport";
        frame.style.cssText = `width:${width}px;height:900px;border:0;display:block;color-scheme:light`;
        frame.src = url;
        document.body.appendChild(frame);
      JS
    end

    def figure_height
      evaluate_script("document.querySelector('figure[data-controller=hero-demo]').offsetHeight")
    end
end
