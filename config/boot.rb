ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# COVERAGE=1 bin/rails test:all measures coverage (config in .simplecov). It
# starts here, not in test/test_helper.rb, because `bin/rails test` loads the
# app before the helper and every file loaded by then would read as uncovered.
require "simplecov" if ENV["COVERAGE"]

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
