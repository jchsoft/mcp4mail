# frozen_string_literal: true

module McpTools
  # Answers "who is Marie" from the sender and recipient headers already in the local index, so
  # there is nothing for the user to configure and no address book to sync. No contacts table: the
  # gin trigram index on mail_messages.search_text (which holds every participant's name and
  # address) narrows the messages first, and only those few rows are unpacked into participants and
  # grouped by address. That stays fast enough per account that a second aggregate to keep fresh
  # would only add staleness.
  class SearchContacts < ApplicationTool
    DEFAULT_LIMIT = 10
    MAX_LIMIT = 25

    tool_name "search_contacts"
    title "Search contacts"

    description <<~TEXT.squish
      Find people you have exchanged mail with, by name or address. Returns name, address, how many
      indexed messages they appear in, when they were last seen, and whether they wrote to you
      ("from"), you wrote to them ("to") or both. Case and diacritics are ignored, so "Novak"
      finds "Novák". Use it to turn "Marie" into an address before calling search_messages.
    TEXT

    input_schema(
      type: "object",
      properties: {
        account_id: {
          type: "integer",
          description: "Id from list_mail_accounts."
        },
        query: {
          type: "string",
          description: "Part of a name or an address. Every word has to match."
        },
        limit: {
          type: "integer",
          description: "How many contacts to return. Defaults to #{DEFAULT_LIMIT}, never more than #{MAX_LIMIT}."
        }
      },
      required: [ "account_id", "query" ],
      additionalProperties: false
    )

    private
      def call
        return Hitch::MCP::Result.error("Give search_contacts a name or an address to look for.") if terms.empty?

        search_guard.admit!
        rows = contact_rows.map { |row| contact(row) }

        rows_returned!(rows.size)
        search_guard.record_rows(rows.size)
        json_result(contacts: rows)
      end

      def contact(row)
        {
          name: row["name"],
          address: row["address"],
          messages_count: row["messages_count"],
          last_seen_at: row["last_seen_at"]&.iso8601,
          direction: direction(row)
        }
      end

      def direction(row)
        return "both" if row["sent"] && row["received"]

        row["sent"] ? "from" : "to"
      end

      def contact_rows
        conditions = terms.map { "unaccent(lower(participants.name || ' ' || participants.address)) LIKE ?" }
        sql = <<~SQL
          WITH candidates AS (#{candidates.to_sql}),
          participants AS (
            SELECT id, date, lower(from_address) AS address, coalesce(from_name, '') AS name, true AS sent
              FROM candidates WHERE from_address <> ''
            UNION ALL
            SELECT candidates.id, candidates.date, lower(entry ->> 'address'), coalesce(entry ->> 'name', ''), false
              FROM candidates, jsonb_array_elements(candidates.to_addresses || candidates.cc_addresses) AS entry
              WHERE coalesce(entry ->> 'address', '') <> ''
          )
          SELECT participants.address,
                 mode() WITHIN GROUP (ORDER BY participants.name) FILTER (WHERE participants.name <> '') AS name,
                 count(DISTINCT participants.id) AS messages_count,
                 max(participants.date) AS last_seen_at,
                 bool_or(participants.sent) AS sent,
                 bool_or(NOT participants.sent) AS received
            FROM participants
            WHERE #{conditions.join(" AND ")}
            GROUP BY participants.address
            ORDER BY messages_count DESC, last_seen_at DESC NULLS LAST, participants.address
            LIMIT #{limit}
        SQL

        values = terms.map { |term| "%#{ActiveRecord::Base.sanitize_sql_like(term)}%" }
        MailMessage.connection.select_all(MailMessage.sanitize_sql_array([ sql, *values ])).map { |row| cast(row) }
      end

      def cast(row)
        row.merge(
          "messages_count" => row["messages_count"].to_i,
          "last_seen_at" => row["last_seen_at"].presence && Time.zone.parse(row["last_seen_at"].to_s)
        )
      end

      def candidates
        MailMessage.for_user(current_user).where(mail_account_id: mail_account.id).search(query)
                   .select(:id, :date, :from_name, :from_address, :to_addresses, :cc_addresses)
      end

      def terms
        @terms ||= MailMessage.normalize_search_text(query).split.uniq
      end

      def query
        arguments["query"].to_s.strip
      end

      def limit
        arguments["limit"].nil? ? DEFAULT_LIMIT : arguments["limit"].to_i.clamp(1, MAX_LIMIT)
      end
  end
end
