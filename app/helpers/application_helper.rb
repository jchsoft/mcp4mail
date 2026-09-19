module ApplicationHelper
  # The address a visitor pastes into their AI client, in the short form the
  # landing page prints: "mcp4mail.online/mcp". It is the very value the
  # connector runs on - Hitch.configuration.resource_uri, the same one
  # connect_ai hands out - so the two can never drift apart, and the locale
  # files interpolate it instead of carrying the host as a literal a translator
  # would have to keep in step with the deployment.
  def connector_address
    Hitch.configuration.resource_uri.sub(%r{\Ahttps?://}, "")
  end
end
