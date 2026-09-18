# frozen_string_literal: true

# Tools are listed and callable only when registered here. Generate one with
# `bin/rails generate hitch:tool NAME`, then make it inherit McpTools::ApplicationTool.
#
# mcp4mail ships read-only: registering a tool that is not an ApplicationTool, or that
# declares itself anything but read-only and non-destructive, fails at boot.
class McpToolRegistry < Hitch::MCP::Registry
  def self.register(tool_class = nil, scopes: nil)
    unless tool_class.is_a?(Class) && tool_class < McpTools::ApplicationTool && tool_class.read_only?
      raise ArgumentError, "#{tool_class.inspect} must be a read-only McpTools::ApplicationTool"
    end

    super
  end

  register McpTools::GetAttachment, scopes: [ "mcp" ]
  register McpTools::GetMailAccount, scopes: [ "mcp" ]
  register McpTools::GetMessage, scopes: [ "mcp" ]
  register McpTools::ListMailAccounts, scopes: [ "mcp" ]
  register McpTools::SearchContacts, scopes: [ "mcp" ]
  register McpTools::SearchMessages, scopes: [ "mcp" ]
end
