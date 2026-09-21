# Which OAuth client has touched which mailbox, from which address, and since when. The first
# sighting of a client on a mailbox emails the owner; a known client showing up from a new
# address is only recorded - a laptop on the move would otherwise mail on every network.
class McpClientSighting < ApplicationRecord
  belongs_to :user
  belongs_to :mail_account

  # Called on every tool call that reached a mailbox, so the steady state is a single
  # INSERT ... ON CONFLICT DO NOTHING. The mail is only enqueued, never delivered inline.
  def self.record!(context:, mail_account_id:)
    inserted = insert_all(
      [ { user_id: context.principal.id, mail_account_id:, client_id: context.client_id,
          remote_ip: context.remote_ip, first_seen_at: Time.current } ],
      unique_by: :index_mcp_client_sightings_uniqueness,
      returning: :id
    )
    return if inserted.empty?

    known_client = where(mail_account_id:, client_id: context.client_id).where.not(id: inserted.first["id"]).exists?
    McpClientAlertsMailer.new_client(find(inserted.first["id"])).deliver_later unless known_client
  end

  # What the client called itself when it registered; the bare id if that row is gone.
  def client_name
    Hitch::Client.find_by(client_id:)&.client_name.presence || client_id
  end
end
