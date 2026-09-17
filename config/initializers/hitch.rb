# frozen_string_literal: true

# hitch-rails: OAuth 2.1 authorization server + authenticated /mcp endpoint for
# AI connectors (Claude, ChatGPT, Grok, Cursor). Pre-1.0 - follow the gem's
# docs/upgrading/* on every version bump.
Hitch.configure do |config|
  # RFC 8707 audience. Matched exactly (scheme, host, port, path), so a local
  # tunnel for a Claude / Grok round trip sets HITCH_RESOURCE_URI to its public
  # https URL. Plain http is accepted for loopback hosts in development and test.
  config.resource_uri = ENV.fetch("HITCH_RESOURCE_URI") do
    Rails.env.production? ? "https://mcp4mail.online/mcp" : "http://localhost:3000/mcp"
  end

  config.brand_name = "mcp4mail"

  # The consent screen resolves the user through our Authentication concern.
  config.principal_method = :current_user
  config.login_path = "/session/new"

  # Exact browser origins; Hitch accepts no wildcards, so subdomains are listed.
  config.allowed_origins = %w[
    https://claude.ai
    https://chatgpt.com
    https://chat.openai.com
    https://grok.com
    https://x.ai
    https://www.x.ai
  ]

  # CIMD for MCP 2026-07-28 clients (Grok, Cursor); DCR because Claude and
  # ChatGPT still register dynamically.
  config.client_id_metadata_enabled = true
  config.dynamic_client_registration_enabled = true

  config.mcp.enabled = true
  config.mcp.registry = "McpToolRegistry"
  config.mcp.server_info = { "name" => "mcp4mail", "version" => "1.0.0" }
end

# /oauth/authorize has no account-scoped URL, so Hitch screens (consent,
# device activation) render in the public layout.
Rails.application.config.to_prepare do
  Hitch::ApplicationController.layout "public"
end
