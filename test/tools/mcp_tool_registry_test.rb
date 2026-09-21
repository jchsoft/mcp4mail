require "test_helper"

class McpToolRegistryTest < ActiveSupport::TestCase
  test "every registered tool is an application tool that is read-only or declares writes" do
    McpToolRegistry.declarations.each do |declaration|
      tool = declaration.class_name.constantize

      assert tool < McpTools::ApplicationTool, declaration.class_name
      assert tool.read_only? || tool.write_tool?, declaration.class_name
    end
  end

  test "every registered tool declares a human title" do
    McpToolRegistry.declarations.each do |declaration|
      tool = declaration.class_name.constantize

      assert tool.title.present?, "#{declaration.class_name} has no title annotation"
      assert_equal tool.title, McpToolRegistry.title_for(tool.tool_name)
    end
  end

  test "a tool name with no tool behind it still reads as words" do
    assert_equal "Send mail", McpToolRegistry.title_for("send_mail")
  end

  test "accepts a tool that declares write_tool, announcing it is not read-only" do
    writer = Class.new(McpTools::ApplicationTool) do
      def self.name = "FlagMessage"
      title "Flag message"
      write_tool destructive: false
    end

    registry = Class.new(McpToolRegistry)
    registry.register(writer, scopes: [ "mcp" ])

    assert_equal [ "FlagMessage" ], registry.declarations.map(&:class_name)
    assert_equal({ title: "Flag message", read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false },
      writer.annotations)
    assert writer.write_tool?
    assert_not writer.read_only?
  end

  test "write_tool insists on an answer for destructive" do
    assert_raises(ArgumentError) { Class.new(McpTools::ApplicationTool) { write_tool destructive: nil } }
  end

  test "refuses to register a tool that sets write annotations without declaring write_tool" do
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
