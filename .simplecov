# Loaded by `require "simplecov"` in config/boot.rb when COVERAGE=1.
# The report lands in coverage/index.html.
SimpleCov.start "rails" do
  enable_coverage :branch
  group "Services", "app/services"
  group "MCP tools", "app/tools"
end
