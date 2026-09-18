require "test_helper"
require "hitch/mcp/test_helper"

# Deleting an account has to reach the AI clients connected to it, not only the database:
# a token minted before the deletion must stop working the moment the button is pressed.
class AccountDeletionTest < ActionDispatch::IntegrationTest
  include Hitch::MCP::TestHelper

  setup do
    McpQuota.store_override = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @token = mint_mcp_token(principal: @user)
  end

  teardown { McpQuota.store_override = nil }

  test "an MCP call with a token minted before the deletion is refused afterwards" do
    post_mcp(method: "tools/list", token: @token)
    assert_response :success

    sign_in_as @user
    delete account_path
    assert_redirected_to root_path

    post_mcp(method: "tools/list", token: @token)
    assert_response :unauthorized
  end
end
