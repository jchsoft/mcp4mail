# Copy-paste instructions for connecting an AI client to the MCP endpoint. Public, so the
# instructions can be read (and linked to from support replies) before signing up.
class ConnectAiController < ApplicationController
  allow_unauthenticated_access

  CLIENTS = %w[ claude chatgpt grok cursor ].freeze

  def show
    @server_url = Hitch.configuration.resource_uri
    @clients = CLIENTS
  end
end
