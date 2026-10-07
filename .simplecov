# Loaded by `require "simplecov"` in config/boot.rb when COVERAGE=1.
# The report lands in coverage/index.html.
SimpleCov.start "rails" do
  enable_coverage :branch
  group "Services", "app/services"
  group "MCP tools", "app/tools"

  # The ratchet: achieved 99.51 % line / 89.86 % branch, minus 0.5. It only
  # applies to a run of the whole suite (COVERAGE_MINIMUM=1, set by bin/ci),
  # because the unit and system tests alone each cover less than the total.
  # Raise the numbers when coverage goes up; never lower them to land a PR.
  minimum_coverage line: 99.0, branch: 89.3 if ENV["COVERAGE_MINIMUM"]
end
