require "test_helper"

class McpToolRegistryTest < ActiveSupport::TestCase
  test "every registered tool is a read-only application tool" do
    McpToolRegistry.declarations.each do |declaration|
      tool = declaration.class_name.constantize

      assert tool < McpTools::ApplicationTool, declaration.class_name
      assert tool.read_only?, declaration.class_name
    end
  end

  test "refuses to register a tool that declares writes" do
    writer = Class.new(McpTools::ApplicationTool) do
      def self.name = "SendMail"
      annotations read_only_hint: false, destructive_hint: true
    end

    assert_raises(ArgumentError) { Class.new(McpToolRegistry).register(writer, scopes: [ "mcp" ]) }
  end

  test "refuses to register a tool outside ApplicationTool" do
    raw = Class.new(Hitch::MCP::Tool) { def self.name = "RawTool" }

    assert_raises(ArgumentError) { Class.new(McpToolRegistry).register(raw, scopes: [ "mcp" ]) }
  end
end
