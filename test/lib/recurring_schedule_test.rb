# frozen_string_literal: true

require "test_helper"

class RecurringScheduleTest < ActiveSupport::TestCase
  test "production schedules the sweep of expired account exports" do
    tasks = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production")

    assert_includes tasks.values.map { |task| task["command"] }, "AccountExportFile.sweep"
  end
end
