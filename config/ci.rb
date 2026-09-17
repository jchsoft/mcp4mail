# frozen_string_literal: true

# Run using bin/ci
#
# Local CI configuration for Rails 8.1+
# This runs all tests and checks locally before pushing/merging.

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Precompile test assets", "bin/rails assets:precompile RAILS_ENV=test"

  step "Tests: Rails", "bin/rails test"

  step "Tests: System", "CI=true bin/rails test:system"

  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  step "Clean test assets", "bin/rails assets:clobber"

  # GitHub CLI integration for PR signoffs
  # Requires: gh extension install basecamp/gh-signoff
  if success?
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
