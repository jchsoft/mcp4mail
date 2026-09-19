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

  # The audit log stores the wire name a client called; the activity list shows the title
  # the tool declares. A name with no registered tool behind it (an older event, a tool
  # since removed) still has to read as something, so it falls back to its own words.
  def self.title_for(tool_name)
    titles.fetch(tool_name) { tool_name.to_s.tr("_", " ").upcase_first }
  end

  # Memoized on the class, which the autoloader discards on every reload.
  def self.titles
    @titles ||= declarations.each_with_object({}) do |declaration, map|
      tool_class = declaration.class_name.constantize
      map[tool_class.tool_name] = tool_class.title if tool_class.title
    end.freeze
  end
end
