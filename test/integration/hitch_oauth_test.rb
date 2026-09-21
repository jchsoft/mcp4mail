require "test_helper"
require "hitch/mcp/test_helper"

class HitchOauthTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  REDIRECT_URI = "http://127.0.0.1:9999/callback"

  setup do
    host! URI(Hitch.configuration.resource_uri).then { |uri| "#{uri.host}:#{uri.port}" }
    Hitch::Client.register!(client_id: "test-probe", client_name: "Test Probe", redirect_uris: [ REDIRECT_URI ])
  end

  test "authorization server metadata answers" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    metadata = response.parsed_body
    assert_equal "http://localhost:3000", metadata["issuer"]
    assert_includes metadata["code_challenge_methods_supported"], "S256"
    assert metadata["registration_endpoint"].present?, "DCR must be advertised"
    assert metadata["client_id_metadata_document_supported"], "CIMD must be advertised"
  end

  test "protected resource metadata answers" do
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    assert_equal Hitch.configuration.resource_uri, response.parsed_body["resource"]
  end

  test "consent screen renders for a signed-in user" do
    sign_in_as users(:one)

    get "/oauth/authorize", params: authorize_params

    assert_response :success
    assert_select "h1", "Connect Local Development"
    assert_select "button", "Approve access"
    assert_includes response.body, "mcp4mail"
  end

  test "consent screen sends a signed-out visitor to sign in" do
    get "/oauth/authorize", params: authorize_params

    assert_redirected_to "/session/new"
  end

  test "mcp endpoint refuses a request without a bearer token" do
    post "/mcp", params: "{}", headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
    assert_match(/Bearer/, response.headers["WWW-Authenticate"])
  end

  test "mcp endpoint lists tools for a minted token" do
    post_mcp method: "tools/list", token: mint_mcp_token(principal: users(:one))

    assert_response :success
    assert_includes response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }, "list_mail_accounts"
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
