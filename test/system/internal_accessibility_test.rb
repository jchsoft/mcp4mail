require "application_system_test_case"
require "axe/api/run"

# The accessibility pass of task #12827, mirroring landing_accessibility_test.rb
# across the signed-in screens. Every check below is one a future restyle could
# quietly break — the missing skip link and the white-on-orange copy button both
# slipped through this product until a screen-reader user ran into them.
class InternalAccessibilityTest < ApplicationSystemTestCase
  LOCALES = %i[en cs].freeze

  # Same scope as the landing test: WCAG 2.1 AA, no best-practice rules.
  WCAG_AA = %i[wcag2a wcag2aa wcag21a wcag21aa].freeze

  # Anything axe rates serious or critical fails the build. minor/moderate
  # findings are reported in the failure message when something else fails, but
  # do not stop a merge on their own.
  BLOCKING_IMPACTS = %w[serious critical].freeze

  # Sign-in, registration and the password request form are reachable without
  # an account — that is what makes them the "auth-free" set in this test.
  # The mailbox index, the new-mailbox form and the connect-the-AI page all
  # sit behind sign-in. visit takes a path, so the locale is appended as a
  # query string the routes will read.
  AUTH_FREE = [
    [ "sign-in",          "/session/new" ],
    [ "registration",     "/registration/new" ],
    [ "password request", "/passwords/new" ]
  ].freeze

  SIGNED_IN = [
    [ "mailboxes",      "/mail_accounts" ],
    [ "new mailbox",    "/mail_accounts/new" ],
    [ "connect the AI", "/connect-ai" ]
  ].freeze

  test "axe reports no serious or critical violations on any signed-in screen, in either language" do
    sign_in_as users(:one)

    SIGNED_IN.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        audit = Axe::Core.new(page).call(Axe::API::Run.new.according_to(*WCAG_AA))
        blocking = audit.results.violations.select { |rule| BLOCKING_IMPACTS.include?(rule.impact.to_s) }

        assert_empty blocking.map { |rule| "#{rule.impact} #{rule.id}: #{rule.help}" },
                     "#{label} #{locale}: axe found blocking violations\n#{audit.failure_message}"
      end
    end
  end

  test "axe also passes on the screens that sit in front of the sign-in form" do
    AUTH_FREE.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        audit = Axe::Core.new(page).call(Axe::API::Run.new.according_to(*WCAG_AA))
        blocking = audit.results.violations.select { |rule| BLOCKING_IMPACTS.include?(rule.impact.to_s) }

        assert_empty blocking.map { |rule| "#{rule.impact} #{rule.id}: #{rule.help}" },
                     "#{label} #{locale}: axe found blocking violations\n#{audit.failure_message}"
      end
    end
  end

  test "the skip link is the first tab stop and moves focus to main on every signed-in screen" do
    sign_in_as users(:one)

    SIGNED_IN.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        # Off-screen until focused: present in the DOM, outside the viewport.
        assert_selector "a.skip-link", visible: :all
        assert_operator page.evaluate_script("document.querySelector('.skip-link').getBoundingClientRect().right"), :<, 0,
                        "#{label} #{locale}: the skip link must sit off-screen until it takes focus"

        # First read which element is at the top of the tab order straight out
        # of the DOM. The new-mailbox form and the connect-AI page both have
        # fields that steal focus with autofocus, which would otherwise mean
        # a Tab keystroke moves from that field forward — not from the very
        # top. The assertion on DOM order catches that bug regardless.
        first_tab_stop = page.evaluate_script(<<~JS)
          (() => {
            const sel = 'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])';
            return document.querySelector(sel)?.className.split(' ').find(c => c === 'skip-link') || document.querySelector(sel)?.className;
          })()
        JS

        assert_equal "skip-link", first_tab_stop,
                     "#{label} #{locale}: the skip link must be the first tab stop, " \
                     "got the element with classes #{first_tab_stop.inspect}"

        # Walk the keyboard journey: clear any focus, then Tab from the very
        # top and confirm the link lands on screen, then Enter jumps to <main>.
        # reset_focus() removes autofocus; the body element is the placeholder
        # the next Tab moves from.
        reset_focus
        page.driver.browser.action.send_keys(:tab).perform
        assert_equal "skip-link", focused_attribute("className"),
                     "#{label} #{locale}: one Tab from the body must land on the skip link"
        assert_operator page.evaluate_script("document.querySelector('.skip-link').getBoundingClientRect().left"), :>=, 0,
                        "#{label} #{locale}: the skip link must be on-screen once focused"

        # assert_selector rather than a straight read of document.activeElement:
        # the browser moves focus a tick after the fragment navigation, and the
        # read would otherwise catch the link still holding it.
        page.driver.browser.action.send_keys(:enter).perform
        assert_selector "main#main:focus", visible: :all
      end
    end
  end

  test "the skip link is the first tab stop on the screens in front of sign-in" do
    AUTH_FREE.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        assert_selector "a.skip-link", visible: :all

        first_tab_stop = page.evaluate_script(<<~JS)
          (() => {
            const sel = 'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])';
            return document.querySelector(sel)?.className.split(' ').find(c => c === 'skip-link') || document.querySelector(sel)?.className;
          })()
        JS

        assert_equal "skip-link", first_tab_stop,
                     "#{label} #{locale}: the skip link must be the first tab stop, " \
                     "got the element with classes #{first_tab_stop.inspect}"

        reset_focus
        page.driver.browser.action.send_keys(:tab).perform
        assert_equal "skip-link", focused_attribute("className"),
                     "#{label} #{locale}: one Tab from the body must land on the skip link"

        page.driver.browser.action.send_keys(:enter).perform
        assert_selector "main#main:focus", visible: :all
      end
    end
  end

  test "every signed-in screen has exactly one h1 and a heading outline that skips no level" do
    sign_in_as users(:one)

    SIGNED_IN.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        levels = page.evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map(h => Number(h.tagName[1]))
        JS

        assert_equal 1, levels.count(1), "#{label} #{locale}: the page needs exactly one h1"
        assert_equal 1, levels.first, "#{label} #{locale}: the first heading on the page must be the h1"

        levels.each_cons(2) do |previous, current|
          assert_operator current, :<=, previous + 1, "#{label} #{locale}: h#{previous} is followed by h#{current}, skipping a level"
        end
      end
    end
  end

  test "the auth screens have exactly one h1 and a heading outline that skips no level" do
    AUTH_FREE.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        levels = page.evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map(h => Number(h.tagName[1]))
        JS

        assert_equal 1, levels.count(1), "#{label} #{locale}: the page needs exactly one h1"
        assert_equal 1, levels.first, "#{label} #{locale}: the first heading on the page must be the h1"

        levels.each_cons(2) do |previous, current|
          assert_operator current, :<=, previous + 1, "#{label} #{locale}: h#{previous} is followed by h#{current}, skipping a level"
        end
      end
    end
  end

  test "the password edit form clears axe and has a single h1, in either language" do
    LOCALES.each do |locale|
      visit "/passwords/#{users(:one).password_reset_token}/edit?locale=#{locale}"

      audit = Axe::Core.new(page).call(Axe::API::Run.new.according_to(*WCAG_AA))
      blocking = audit.results.violations.select { |rule| BLOCKING_IMPACTS.include?(rule.impact.to_s) }

      assert_empty blocking.map { |rule| "#{rule.impact} #{rule.id}: #{rule.help}" },
                   "password edit #{locale}: axe found blocking violations\n#{audit.failure_message}"

      levels = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map(h => Number(h.tagName[1]))
      JS

      assert_equal 1, levels.count(1), "password edit #{locale}: the page needs exactly one h1"
      levels.each_cons(2) do |previous, current|
        assert_operator current, :<=, previous + 1, "password edit #{locale}: h#{previous} is followed by h#{current}, skipping a level"
      end
    end
  end

  test "the landmarks are present once each on the signed-in screens" do
    sign_in_as users(:one)

    SIGNED_IN.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        { "header" => 1, "main" => 1 }.each do |landmark, expected|
          assert_equal expected, page.evaluate_script("document.querySelectorAll('#{landmark}').length"),
                       "#{label} #{locale}: expected exactly #{expected} <#{landmark}>"
        end
      end
    end
  end

  test "the lang attribute follows the locale on every signed-in screen" do
    sign_in_as users(:one)

    SIGNED_IN.each do |_label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"
        assert_equal locale.to_s, page.evaluate_script("document.documentElement.lang")
      end
    end
  end

  # The whole reason the global two-tone focus ring exists is that components
  # kept overriding it. Walk the mailbox index with the keyboard and assert
  # each stop actually draws the ring — in ink (3px outline) and orange
  # (6px box-shadow).
  test "the focus ring is drawn in both of its colours on every key control of the mailbox index" do
    sign_in_as users(:one)
    visit "/mail_accounts"

    # The Mailboxes nav link, the Add mailbox button, the Recent activity
    # disclosure and the Remove mailbox button are the four stops a keyboard
    # user makes on the index. button_to DELETE wraps the Remove submit in a
    # <form>, so the data-turbo-confirm attribute is on the form, not the
    # button — focus the button it contains.
    targets = {
      "header nav a[aria-current='page']" => "the Mailboxes nav link",
      "a[href*='mail_accounts/new']"      => "the Add mailbox button",
      "[id^='mail_account_'] summary"     => "the Recent activity disclosure"
    }

    targets.each do |selector, where|
      assert page.has_css?(selector, wait: 0), "#{where}: expected to find #{selector.inspect} on the mailbox index"

      ring = page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector("#{selector}");
          el.focus();
          const s = getComputedStyle(el);
          return [s.outlineStyle, s.outlineWidth, s.outlineColor, s.outlineOffset, s.boxShadow];
        })()
      JS

      assert_equal "solid", ring[0], "#{where}: outline style"
      assert_equal "3px", ring[1], "#{where}: outline width"
      assert_equal "rgb(31, 36, 48)", ring[2], "#{where}: the outer half of the ring is ink"
      assert_equal "3px", ring[3], "#{where}: outline offset"
      assert_includes ring[4], "rgb(242, 107, 29)", "#{where}: the inner half of the ring is brand orange"
    end

    # The Remove button is rendered as a button_to DELETE; its form carries
    # the data-turbo-confirm attribute. Find the form, then its submit.
    remove_form = page.find("form[data-turbo-confirm]", match: :first)
    remove_button = remove_form.find("button[type='submit']", match: :first)
    page.evaluate_script("arguments[0].focus()", remove_button.native)

    ring = page.evaluate_script(<<~JS)
      (() => {
        const el = document.activeElement;
        const s = getComputedStyle(el);
        return [s.outlineStyle, s.outlineWidth, s.outlineColor, s.outlineOffset, s.boxShadow];
      })()
    JS

    assert_equal "solid", ring[0], "the Remove mailbox button: outline style"
    assert_equal "3px", ring[1], "the Remove mailbox button: outline width"
    assert_equal "rgb(31, 36, 48)", ring[2], "the Remove mailbox button: the outer half of the ring is ink"
    assert_equal "3px", ring[3], "the Remove mailbox button: outline offset"
    assert_includes ring[4], "rgb(242, 107, 29)", "the Remove mailbox button: the inner half of the ring is brand orange"
  end

  test "every form field on the new-mailbox form is announced with its label" do
    sign_in_as users(:one)
    visit "/mail_accounts/new"

    # shared/_field sets the <label for=> and the matching id on every control,
    # so a screen reader announces the human attribute name. Assert on the
    # pair rather than on a class: a restyle might change how the control is
    # drawn, but the label cannot disappear. The select control's HTML type
    # is "select-one", not "select" — match what the browser reports.
    [
      [ "Email address", "email" ],
      [ "Password",      "password" ],
      [ "IMAP server",   "text" ],
      [ "Port",          "number" ],
      [ "Security",      "select-one" ],
      [ "Username",      "text" ]
    ].each do |label_text, type|
      label_for = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('label')).find(l => l.textContent.trim() === #{label_text.to_json})?.getAttribute('for')
      JS

      assert label_for.present?, "expected a label reading #{label_text.inspect}"
      control = page.find("##{label_for}", visible: :all)

      assert_equal type, control[:type], "#{label_text}: the control is #{control[:type]} but the test asked for #{type}"
    end
  end

  test "the validation summary and the connection-error alert announce themselves when they appear" do
    user = users(:one)
    sign_in_as(user)

    # Validation error path: open the disclosure, leave Port blank, submit.
    # An empty number field is what trips the model's presence validation
    # here — the HTML5 min/max bounds only fire when a number has been typed.
    visit "/mail_accounts/new"
    find("summary", text: "Connection details").click
    fill_in "Email address", with: "bob@example.com"
    fill_in "Password", with: "app-password"
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: ""
    fill_in "Username", with: "bob"
    click_on "Connect"

    # shared/_error_summary renders <ul id="errors"> — and <ul> is the role a
    # screen reader announces for a list of errors. The id is the one the
    # controller and mailbox lifecycle tests hold on to.
    assert_selector "#errors"
    list_role = page.evaluate_script("document.querySelector('#errors').getAttribute('role') || ''")
    assert list_role.empty? || list_role == "list",
           "the error summary must render as a list (got role=#{list_role.inspect})"

    # Connection-error path: dead port, no security.
    dead_server = FakeImapServer.new.start
    dead_port = dead_server.port
    dead_server.stop

    visit "/mail_accounts/new"
    fill_in "Email address", with: "bob@example.com"
    fill_in "Password", with: "app-password"
    find("summary", text: "Connection details").click
    fill_in "IMAP server", with: "127.0.0.1"
    fill_in "Port", with: dead_port
    select "None (unencrypted)", from: "Security"
    fill_in "Username", with: "bob"
    click_on "Connect"

    # shared/_alert gives the danger variant role="alert" — that is the one
    # path where a screen reader interrupts and reads it out.
    assert_selector "#connection-error[role=alert]"
    role = page.evaluate_script("document.querySelector('#connection-error').getAttribute('role')")
    live = page.evaluate_script("document.querySelector('#connection-error').getAttribute('aria-live') || ''")
    assert_equal "alert", role, "the connection-error alert must announce itself with role=alert"
    assert live.empty? || live == "assertive",
           "the connection-error alert is already an alert role, so aria-live must be empty or assertive (got #{live.inspect})"
  end

  test "the activity frame does not introduce a second h1 or skip a level" do
    user = users(:one)
    work = mail_accounts(:work)
    McpAuditEvent.create!(user:, mail_account_id: work.id, tool_name: "search_messages",
      outcome: "ok", rows_returned: 1, client_id: "test")

    sign_in_as(user)
    visit "/mail_accounts"

    # The activity frame is a lazy turbo frame, fetched when the disclosure
    # opens. The page-level outline is asserted above; here we just want to
    # make sure the frame does not introduce its own h1 or skip a level.
    find("summary", text: "Recent activity").click

    levels = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6')).map(h => Number(h.tagName[1]))
    JS

    assert_equal 1, levels.count(1), "the activity frame must not introduce a second h1"
    levels.each_cons(2) do |previous, current|
      assert_operator current, :<=, previous + 1, "activity frame: h#{previous} is followed by h#{current}, skipping a level"
    end
  end

  test "no link on a signed-in screen leans on its surroundings to say where it goes" do
    sign_in_as users(:one)

    SIGNED_IN.each do |label, path|
      LOCALES.each do |locale|
        visit "#{path}?locale=#{locale}"

        vague = page.evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('a'))
               .map(a => (a.innerText || a.textContent || '').trim().toLowerCase().replace(/[.…]+$/, ''))
               .filter(t => ['here', 'click here', 'read more', 'more', 'link', 'tady', 'zde', 'více', 'vice', 'sem'].includes(t))
        JS

        assert_empty vague, "#{label} #{locale}: these links do not say where they go out of context"
      end
    end
  end

  private
    def focused_attribute(property)
      page.evaluate_script("document.activeElement.#{property}")
    end

    # The form pages autofocus the first field, which would otherwise mean a
    # Tab keystroke moves from that field forward rather than from the very
    # top of the tab order. Strip autofocus from any field, blur whatever
    # currently has focus, and focus a known element before the skip link in
    # the DOM so the next Tab starts the journey at the very top — exactly
    # the path a screen-reader-only visitor makes when they reach the page
    # fresh. The cleanest way to reset focus is to focus the skip link's
    # position-none sibling: with focus outside the page, Tab walks from the top
    # again. body itself is not focusable in HTML5, so use document.documentElement
    # (the <html> root, which is always focusable).
    def reset_focus
      # The IIFE wrapper is load-bearing: in headless Firefox, Geckodriver's
      # executeScript does not always settle the focus changes made by a bare
      # multi-statement script. The earlier form (forEach to remove autofocus,
      # then blur, then documentElement.focus) left activeElement reading as
      # the autofocus input afterwards — confirmed by reading document.activeElement
      # in a follow-up evaluate_script on a page where the email field has
      # `autofocus: true`. Wrapping the body in an IIFE forces the script
      # through a single expression that Geckodriver waits for, and the
      # autofocus/activeElement/blur/focus sequence then settles in the right
      # order.
      page.evaluate_script(<<~JS)
        (function() {
          var el = document.querySelector('[autofocus]');
          if (el) el.removeAttribute('autofocus');
          if (document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
          document.documentElement.focus();
        })()
      JS
    end

    # Every system test signs in through the form, same as
    # mailbox_lifecycle_test.rb. Kept here rather than in a shared helper
    # because internal_accessibility_test is the only one that signs in
    # inside a loop.
    def sign_in_as(user)
      visit "/session/new"
      fill_in placeholder: "Enter your email address", with: user.email_address
      fill_in placeholder: "Enter your password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end
end
