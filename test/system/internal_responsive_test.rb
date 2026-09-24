require "application_system_test_case"

# landing_responsive_test.rb measures the public page; this is the counterpart
# for the screens behind it, which is where a mailbox owner checks on a phone
# whether their mailbox is still connected. Until now nothing measured the
# signed-in surface below 1024px: the layouts could break at 375 and every other
# test would stay green.
#
# The same iframe #viewport trick, for the same reason: headless Firefox will
# not give us a window narrower than about 500 CSS px, so a window-resized
# "375px" test is really a 500px test. An iframe is its own viewport, so vw
# units, clamp() and media queries resolve against its width, and 375 means 375.
#
# The frame is loaded after the test has visited the same URL in the outer
# window, so it shares the browser's session cookie and the signed-in screens
# stay signed in.
class InternalResponsiveTest < ApplicationSystemTestCase
  PHONE = 375
  TABLET = 768
  WIDTHS = [ PHONE, TABLET ].freeze
  LOCALES = %i[ en cs ].freeze

  # Everything a visitor without a session can reach. The password screen takes
  # a token, which is minted here rather than by going through the mailer. A
  # method rather than a constant: the route helpers inside the lambdas resolve
  # against the test instance, not against the class.
  def signed_out_screens
    {
      "sign-in" => ->(locale) { new_session_url(locale: locale) },
      "registration" => ->(locale) { new_registration_url(locale: locale) },
      "password-new" => ->(locale) { new_password_url(locale: locale) },
      "password-edit" => ->(locale) { edit_password_url(users(:one).password_reset_token, locale: locale) }
    }
  end

  test "the signed-out screens fit a phone and a tablet in both languages" do
    each_screen(signed_out_screens) do |name, width, locale|
      assert_no_sideways_scroll(name, width, locale)
      assert_header_wraps(name, width, locale)
      assert_empty undersized_targets, "#{name} #{locale} at #{width}px has a tap target under 44px: #{undersized_targets.to_sentence}"
      assert_fields_fill_the_column(name, width, locale)
      assert_submit_fills_the_column(name, width, locale) if width == PHONE
    end
  end

  test "the mailbox index stacks its cards and opens its activity" do
    user = users(:one)
    # Two mailboxes, because one card stacks trivially.
    user.mail_accounts.create!(display_name: "Second", host: "imap.example.org", port: 993, ssl: true,
                               username: "one@example.org", password: "fixture-app-password")
    Hitch::Client.register!(client_id: "client-abc", client_name: "Claude Desktop", redirect_uris: [ "https://example.com/cb" ])
    McpAuditEvent.create!(user:, mail_account_id: mail_accounts(:work).id, tool_name: "search_messages",
                          outcome: "ok", rows_returned: 7, client_id: "client-abc")

    sign_in_as user

    each_screen({ "mailboxes" => ->(locale) { mail_accounts_url(locale: locale) } }) do |name, width, locale|
      assert_no_sideways_scroll(name, width, locale)
      assert_header_wraps(name, width, locale)
      assert_equal [ 1, 1 ], row_sizes("ul.grid > li"),
                   "#{name} #{locale} at #{width}px: the mailbox cards must stack, one per row"
      assert_empty undersized_targets, "#{name} #{locale} at #{width}px has a tap target under 44px: #{undersized_targets.to_sentence}"

      # Two mailboxes means two summaries — click the first one's. The list has
      # to have landed before measuring: the placeholder is not the list.
      open_activity_disclosure I18n.t("mail_accounts.index.recent_activity", locale: locale)
      assert_selector "li", text: "Claude Desktop"
      assert_no_sideways_scroll("#{name} with the activity open", width, locale)
    end
  end

  test "the empty mailbox index fits a phone and a tablet" do
    sign_in_as User.create!(email_address: "fresh@example.com", password: "password")

    each_screen({ "mailboxes-empty" => ->(locale) { mail_accounts_url(locale: locale) } }) do |name, width, locale|
      assert_selector "#empty"
      assert_no_sideways_scroll(name, width, locale)
      assert_header_wraps(name, width, locale)
      assert_empty undersized_targets, "#{name} #{locale} at #{width}px has a tap target under 44px: #{undersized_targets.to_sentence}"
    end
  end

  test "the new-mailbox form fits a phone and a tablet, open and closed" do
    sign_in_as users(:one)

    each_screen({ "new-mailbox" => ->(locale) { new_mail_account_url(locale: locale) } }) do |name, width, locale|
      assert_no_sideways_scroll(name, width, locale)
      assert_header_wraps(name, width, locale)
      assert_fields_fill_the_column(name, width, locale)

      # The connection details hold the widest row on the screen: host, port and
      # TLS side by side from sm up.
      find("summary", text: I18n.t("mail_accounts.new.connection_details", locale: locale)).click
      assert_selector "#connection-details[open]"
      assert_no_sideways_scroll("#{name} with the details open", width, locale)
      assert_fields_fill_the_column("#{name} with the details open", width, locale)
      assert_submit_fills_the_column("#{name} with the details open", width, locale) if width == PHONE
      assert_empty undersized_targets, "#{name} #{locale} at #{width}px has a tap target under 44px: #{undersized_targets.to_sentence}"
    end
  end

  test "the connect-AI tablist stays usable on a phone and a tablet" do
    sign_in_as users(:one)

    each_screen({ "connect-ai" => ->(locale) { connect_ai_url(locale: locale) } }) do |name, width, locale|
      assert_selector "[role=tablist]:not([hidden])"
      assert_no_sideways_scroll(name, width, locale)
      assert_header_wraps(name, width, locale)
      assert_empty undersized_targets, "#{name} #{locale} at #{width}px has a tap target under 44px: #{undersized_targets.to_sentence}"

      tabs = all("[role=tab]")
      assert_equal 4, tabs.size
      tabs.each do |tab|
        assert_operator element_box(tab)["right"], :<=, width + 1,
                        "#{name} #{locale} at #{width}px: the #{tab.text} tab runs past the frame"
      end

      # Every client's instructions stay one tap away.
      tabs.each do |tab|
        tab.click
        assert_no_sideways_scroll("#{name} on the #{tab.text} tab", width, locale)
      end
    end
  end

  private
    # Loads each screen in turn, inside a frame of the given width, once per
    # width and language, and captures it once the frame is left again: the
    # screenshot and the window resize it needs belong to the outer document.
    def each_screen(screens, widths: WIDTHS, locales: LOCALES, &block)
      screens.each do |name, url|
        widths.each do |width|
          locales.each do |locale|
            open_viewport(url.call(locale), width)
            within_frame(find("#viewport")) { block.call(name, width, locale) }
            capture!("internal-#{name}-#{locale}-#{width}", width)
          end
        end
      end
    end

    def sign_in_as(user)
      visit new_session_url
      fill_in placeholder: "Enter your email address", with: user.email_address
      fill_in placeholder: "Enter your password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
    end

    def open_viewport(url, width)
      # The window only has to be wide enough to hold the frame.
      page.driver.browser.manage.window.resize_to([ width + 80, 560 ].max, 1400)
      # Visiting the screen first puts the browser on our own host, so the frame
      # is same-origin and carries the session cookie.
      visit url

      page.execute_script(<<~JS, url, width)
        const [src, width] = arguments;
        document.body.replaceChildren();
        document.body.style.margin = "0";
        const frame = document.createElement("iframe");
        frame.id = "viewport";
        frame.style.cssText = `width:${width}px;height:900px;border:0;display:block;color-scheme:light`;
        frame.src = src;
        document.body.appendChild(frame);
      JS

      within_frame(find("#viewport")) { assert_selector "h1" }

      # Grown to its content, the frame never scrolls, so no scrollbar eats into
      # the width we are measuring.
      page.execute_script(<<~JS)
        const frame = document.getElementById("viewport");
        frame.style.height = `${frame.contentDocument.documentElement.scrollHeight}px`;
      JS
    end

    # Firefox clips an element capture to the window, so the window has to be as
    # tall as the frame for the screenshot to hold the whole page. The frame is
    # measured again here: an opened disclosure adds a list to it.
    def capture!(name, width)
      page.execute_script(<<~JS)
        const frame = document.getElementById("viewport");
        frame.style.height = "900px";
        frame.style.height = `${frame.contentDocument.documentElement.scrollHeight}px`;
      JS

      height = page.evaluate_script("document.getElementById('viewport').offsetHeight")
      page.driver.browser.manage.window.resize_to([ width + 80, 560 ].max, height + 40)

      path = screenshot_path(name)
      File.binwrite(path, find("#viewport").native.screenshot_as(:png))
      assert_operator File.size(path), :>, 10_000, "#{path} looks empty"
    end

    def assert_no_sideways_scroll(name, width, locale)
      overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_operator overflow, :<=, 0,
                      "#{name} #{locale} at #{width}px scrolls sideways by #{overflow}px, past: #{overflowing_elements.join(" | ")}"
    end

    # The header may wrap — it has to at 375 — but it wraps inside its own
    # column: content that ran past it would mean no wrap happened at all.
    def assert_header_wraps(name, width, locale)
      excess = page.evaluate_script(<<~JS)
        (() => {
          const header = document.querySelector("header");
          return header.scrollWidth - header.clientWidth;
        })()
      JS
      assert_operator excess, :<=, 1, "#{name} #{locale} at #{width}px: the app header runs past its own column by #{excess}px"
    end

    # A field is `w-full` inside its own row, so it has to measure the row's
    # content box, not a desktop-width box of its own.
    def assert_fields_fill_the_column(name, width, locale)
      narrow = narrower_than_column("form input[type=email], form input[type=password], form input[type=text], form input[type=number], form select")
      assert_empty narrow, "#{name} #{locale} at #{width}px: a field does not use its column: #{narrow.to_sentence}"
    end

    # On a phone the submit control spans the column rather than shrinking to
    # the label; from sm up the design lets it sit at its own width.
    def assert_submit_fills_the_column(name, width, locale)
      narrow = narrower_than_column("form button[type=submit], form input[type=submit]")
      assert_empty narrow, "#{name} #{locale} at #{width}px: the submit button does not use its column: #{narrow.to_sentence}"
    end

    # Everything whose box reaches past either edge of the viewport, named well
    # enough to find in the markup.
    def overflowing_elements
      page.evaluate_script(<<~JS)
        (() => {
          const viewport = document.documentElement.clientWidth;
          return [...document.querySelectorAll("body *")].filter(element => {
            const rect = element.getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) return false;
            return rect.right > viewport + 1 || rect.left < -1;
          }).map(element => `${element.tagName}.${element.className} "${element.textContent.trim().slice(0, 30)}"`);
        })()
      JS
    end

    def narrower_than_column(selector)
      page.evaluate_script(<<~JS)
        (() => {
          return [...document.querySelectorAll("#{selector}")].filter(element => {
            const rect = element.getBoundingClientRect();
            if (rect.width === 0) return false;
            const parent = element.parentElement;
            const style = getComputedStyle(parent);
            const column = parent.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
            return rect.width < column - 2;
          }).map(element => `${element.tagName}[${element.type}] ${Math.round(element.getBoundingClientRect().width)} of ${Math.round(element.parentElement.clientWidth)}`);
        })()
      JS
    end

    # Header chrome, the body's controls and the tablist: all tap targets below
    # lg (GUIDELINES section 2, rule 3). Links inside a sentence are words, not
    # buttons, so `main a` is measured too — they carry max-lg:min-h-11.
    def undersized_targets
      page.evaluate_script(<<~JS)
        (() => {
          return [...document.querySelectorAll("header a, header button, main a, main button, form input[type=submit], summary, [role=tab]")]
            .filter(element => {
              const rect = element.getBoundingClientRect();
              return rect.width > 0 && rect.height > 0 && (rect.height < 44 || rect.width < 44);
            })
            .map(element => `"${element.textContent.trim().slice(0, 24)}" ${Math.round(element.getBoundingClientRect().width)}x${Math.round(element.getBoundingClientRect().height)}`);
        })()
      JS
    end

    # How many items sit in each row of a grid, top to bottom.
    def row_sizes(selector)
      page.evaluate_script(<<~JS)
        (() => {
          const rows = new Map();
          document.querySelectorAll("#{selector}").forEach(element => {
            const top = Math.round(element.getBoundingClientRect().top);
            rows.set(top, (rows.get(top) || 0) + 1);
          });
          return [...rows.entries()].sort((a, b) => a[0] - b[0]).map(entry => entry[1]);
        })()
      JS
    end

    def element_box(element)
      page.evaluate_script(<<~JS, element)
        (() => {
          const rect = arguments[0].getBoundingClientRect();
          return { top: rect.top, left: rect.left, right: rect.right, width: rect.width, height: rect.height };
        })()
      JS
    end
end
