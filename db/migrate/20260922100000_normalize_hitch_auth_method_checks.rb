# hitch-rails writes these checks as `IN ('none', 'client_secret_basic')` on a
# varchar column. Postgres prints that back in a form that does not survive a
# round trip through schema.rb: a database built from migrations and one built
# with db:schema:load dump different text, so `db:prepare` leaves schema.rb
# dirty and bin/ci's signoff refuses to run. Spelling the check with plain text
# literals dumps to the same string whichever way the database was built.
class NormalizeHitchAuthMethodChecks < ActiveRecord::Migration[8.1]
  TABLES = {
    hitch_clients: "hitch_clients_auth_method_check",
    hitch_device_grants: "hitch_device_grants_auth_method_check"
  }.freeze

  def up
    replace_checks "token_endpoint_auth_method::text = ANY (ARRAY['none'::text, 'client_secret_basic'::text])"
  end

  def down
    replace_checks "token_endpoint_auth_method IN ('none', 'client_secret_basic')"
  end

  private

  def replace_checks(expression)
    TABLES.each do |table, name|
      remove_check_constraint table, name: name
      add_check_constraint table, expression, name: name
    end
  end
end
