# The connector address and the few lines a person needs to paste it into their AI client.
# Public, so the instructions can be read (and linked to from support replies) before signing up.
class ConnectAiController < ApplicationController
  allow_unauthenticated_access

  # One tab each, in the order the segmented control shows them. "other" is the
  # catch-all for any MCP client we have not written a menu path for.
  CLIENTS = %w[ claude chatgpt cursor other ].freeze

  def show
    @server_url = Hitch.configuration.resource_uri
    @clients = CLIENTS
  end
end
