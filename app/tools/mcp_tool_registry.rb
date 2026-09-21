# frozen_string_literal: true

# Tools are listed and callable only when registered here. Generate one with
# `bin/rails generate hitch:tool NAME`, then make it inherit McpTools::ApplicationTool.
#
# A tool is either read-only and non-destructive, or it says it writes with `write_tool`
# (and then runs only on mailboxes the owner made writable). Registering a tool that is not
# an ApplicationTool, or one that sets write annotations without declaring write_tool, fails
# at boot.
class McpToolRegistry < Hitch::MCP::Registry
  def self.register(tool_class = nil, scopes: nil)
    unless tool_class.is_a?(Class) && tool_class < McpTools::ApplicationTool && (tool_class.read_only? || tool_class.write_tool?)
      raise ArgumentError, "#{tool_class.inspect} must be an McpTools::ApplicationTool that is read-only or declares write_tool"
    end

    raise ArgumentError, "#{tool_class.name} must declare a human title" if tool_class.title.blank?

    super
  end

  register McpTools::CreateFolder, scopes: [ "mcp" ]
  register McpTools::GetAttachment, scopes: [ "mcp" ]
  register McpTools::GetMailAccount, scopes: [ "mcp" ]
  register McpTools::GetMessage, scopes: [ "mcp" ]
  register McpTools::ListFolders, scopes: [ "mcp" ]
  register McpTools::ListMailAccounts, scopes: [ "mcp" ]
  register McpTools::MoveMessage, scopes: [ "mcp" ]
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
