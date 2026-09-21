require "test_helper"

# Our overrides of hitch-rails' consent and device-activation templates
# (app/views/hitch/): translated in both languages, and still posting exactly
# the fields the gem's controllers read.
class HitchScreensTest < ActionDispatch::IntegrationTest
  REDIRECT_URI = "http://127.0.0.1:9999/callback"

  setup do
    host! URI(Hitch.configuration.resource_uri).then { |uri| "#{uri.host}:#{uri.port}" }
    Hitch::Client.register!(client_id: "test-probe", client_name: "Test Probe", redirect_uris: [ REDIRECT_URI ])
    @device_flow_was = Hitch.configuration.device_authorization_enabled
    Hitch.configuration.device_authorization_enabled = true
    sign_in_as users(:one)
  end

  teardown do
    Hitch.configuration.device_authorization_enabled = @device_flow_was
  end

  test "the consent screen asks in English and keeps the gem's form" do
    get "/oauth/authorize", params: authorize_params

    assert_response :success
    assert_select "h1", "Connect Local Development"
    assert_select "li", text: /Search and read the mail/
    assert_select "li code", "mcp"
    assert_select "form[action='/oauth/authorize'][data-turbo=false]" do
      assert_select "input[type=hidden][name=state][value=xyz]"
      assert_select "button:not([name])", "Approve access"
      assert_select "button[name=decision][value=deny]", "Deny access"
    end
  end

  test "the consent screen speaks Czech" do
    get "/oauth/authorize", params: authorize_params, headers: { "Accept-Language" => "cs" }

    assert_response :success
    assert_select "h1", "Připojit Local Development"
    assert_select "button", "Schválit přístup"
    assert_select "button", "Zamítnout přístup"
  end

  test "denying on the consent screen still reaches the client" do
    get "/oauth/authorize", params: authorize_params
    post "/oauth/authorize", params: authorize_params.merge(decision: "deny")

    assert_response :redirect
    assert_match(/\A#{Regexp.escape(REDIRECT_URI)}\?.*error=access_denied/, response.location)
  end

  test "code entry carries the warning in both languages" do
    get "/activate"
    assert_response :success
    assert_select "h1", "Connect a device"
    assert_select "p", text: /Only enter a code you asked a device for/
    assert_select "input#user_code.font-code"

    get "/activate", headers: { "Accept-Language" => "cs" }
    assert_select "h1", "Připojit zařízení"
    assert_select "p", text: /Zadávejte jen kód, o který jste zařízení sami požádali/
    assert_select "button", "Ověřit kód"
  end

  test "an unknown code answers with a translated alert" do
    post "/activate", params: { user_code: "ABCD-EFGH" }, headers: { "Accept-Language" => "cs" }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Tento kód nečeká na schválení/
  end

  test "an unverified device sees its code large and cannot be approved" do
    grant = Hitch::DeviceGrant.mint!(client_id: "test-probe", scopes: "mcp", resource_uri: Hitch.configuration.resource_uri)
    code = Hitch::DeviceGrant.display_user_code(grant.raw_user_code)

    post "/activate", params: { user_code: code }

    assert_response :success
    assert_select "h1", "Approve this device?"
    assert_select "p.font-code", code
    assert_select "p", text: /could not be verified right now/
    assert_select "button[value=approve]", count: 0
    assert_select "button[value=deny]", "Deny access"
  end

  test "an operator's client can be approved and the outcome is translated" do
    Hitch::Client.register_confidential!(client_id: "operator-probe", client_name: "Operator Probe",
                                         redirect_uris: [ REDIRECT_URI ], operator_registered: true)
    grant = Hitch::DeviceGrant.mint!(client_id: "operator-probe", scopes: "mcp", resource_uri: Hitch.configuration.resource_uri)
    code = Hitch::DeviceGrant.display_user_code(grant.raw_user_code)

    post "/activate", params: { user_code: code }
    assert_select "strong", "Operator Probe"
    assert_select "li", text: /Search and read the mail/
    assert_select "button[value=approve]", "Approve access"

    post "/activate", params: { user_code: code, decision: "approve" }, headers: { "Accept-Language" => "cs" }
    assert_response :success
    assert_select "h1", "Přístup schválen"
  end

  private
    def authorize_params
      {
        response_type: "code",
        client_id: "test-probe",
        redirect_uri: REDIRECT_URI,
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("verifier" * 8), padding: false),
        code_challenge_method: "S256",
        state: "xyz",
        resource: Hitch.configuration.resource_uri,
        scope: "mcp"
      }
    end
end
