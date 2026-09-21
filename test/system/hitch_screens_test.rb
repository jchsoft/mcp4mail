require "application_system_test_case"

# The consent and device-activation screens on a phone, in both languages. The
# consent screen is usually opened straight from the AI client, often on a
# phone, so 375px is the width that matters. As in landing_responsive_test.rb,
# the page is loaded in an iframe of that exact width: headless Firefox will not
# give a narrower window than about 500px.
class HitchScreensTest < ApplicationSystemTestCase
  PHONE = 375
  REDIRECT_URI = "http://127.0.0.1:9999/callback"

  setup do
    # Hitch answers only on the host and port of its resource URI, so point it
    # at the server Capybara started.
    @resource_uri_was = Hitch.configuration.resource_uri
    @device_flow_was = Hitch.configuration.device_authorization_enabled
    Hitch.configuration.resource_uri = "#{Capybara.current_session.server.base_url}/mcp"
    Hitch.configuration.device_authorization_enabled = true
    Hitch::Client.register_confidential!(client_id: "operator-probe", client_name: "Operator Probe",
                                         redirect_uris: [ REDIRECT_URI ], operator_registered: true)

    visit new_session_url
    fill_in placeholder: "Enter your email address", with: users(:one).email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end

  teardown do
    Hitch.configuration.resource_uri = @resource_uri_was
    Hitch.configuration.device_authorization_enabled = @device_flow_was
  end

  test "the consent screen fits a phone and stacks its decision" do
    { en: [ "Approve access", "Deny access" ], cs: [ "Schválit přístup", "Zamítnout přístup" ] }.each do |locale, (approve, deny)|
      in_phone_frame("/oauth/authorize?#{authorize_query}", locale) do
        assert_no_sideways_scroll(locale)
        approve_box = box(find("button", exact_text: approve))
        deny_box = box(find("button", exact_text: deny))
        assert_operator deny_box["top"], :>=, approve_box["top"] + approve_box["height"], "#{locale}: the pills should stack"
        assert_operator approve_box["height"], :>=, 44
        screenshot!("hitch-consent-#{locale}-#{PHONE}")
      end
    end
  end

  test "the activation code reads large and fits a phone" do
    { en: "Check the code", cs: "Ověřit kód" }.each do |locale, submit|
      grant = Hitch::DeviceGrant.mint!(client_id: "operator-probe", scopes: "mcp", resource_uri: Hitch.configuration.resource_uri)
      code = Hitch::DeviceGrant.display_user_code(grant.raw_user_code)

      in_phone_frame("/activate?user_code=#{code}", locale) do
        assert_no_sideways_scroll(locale)
        screenshot!("hitch-activate-#{locale}-#{PHONE}")
        click_button submit

        shown = find("p.font-code", exact_text: code)
        assert_no_sideways_scroll(locale)
        assert_operator evaluate_script("parseFloat(getComputedStyle(arguments[0]).fontSize)", shown), :>=, 28
        assert_match(/monospace/, evaluate_script("getComputedStyle(arguments[0]).fontFamily", shown))
      end
      screenshot!("hitch-activate-confirm-#{locale}-#{PHONE}")
    end
  end

  private
    def in_phone_frame(path, locale)
      # Tall enough to hold the whole frame: Firefox misplaces a click on an
      # element of an iframe that sits below the window's fold.
      page.driver.browser.manage.window.resize_to(PHONE + 180, 1600)
      visit root_url(locale: locale)
      page.execute_script(<<~JS, path, PHONE)
        const [src, width] = arguments;
        document.body.replaceChildren();
        document.body.style.margin = "0";
        const frame = document.createElement("iframe");
        frame.id = "viewport";
        frame.style.cssText = `width:${width}px;height:1400px;border:0;display:block;color-scheme:light`;
        frame.src = src;
        document.body.appendChild(frame);
      JS
      within_frame(find("#viewport")) do
        assert_selector "h1"
        yield
      end
    end

    def assert_no_sideways_scroll(locale)
      overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_operator overflow, :<=, 0, "#{locale} at #{PHONE}px scrolls sideways by #{overflow}px"
    end

    def box(element)
      evaluate_script(<<~JS, element)
        (() => {
          const rect = arguments[0].getBoundingClientRect();
          return { top: rect.top, height: rect.height };
        })()
      JS
    end

    def authorize_query
      {
        response_type: "code",
        client_id: "operator-probe",
        redirect_uri: REDIRECT_URI,
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("verifier" * 8), padding: false),
        code_challenge_method: "S256",
        state: "xyz",
        resource: Hitch.configuration.resource_uri,
        scope: "mcp"
      }.to_query
    end
end
