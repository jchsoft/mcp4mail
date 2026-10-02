# What the AI may change in a writable mailbox, one switch per group of write tools. All on by
# default, so every mailbox that is writable today keeps all its powers.
class AddAiPermissionsToMailAccounts < ActiveRecord::Migration[8.1]
  COLUMNS = %i[ ai_can_flag ai_can_organize ai_can_draft ai_can_send ai_can_trash ].freeze

  def change
    COLUMNS.each { |column| add_column :mail_accounts, column, :boolean, default: true, null: false }
  end
end
