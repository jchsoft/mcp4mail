# frozen_string_literal: true

module McpTools
  # Headers only, never bodies. One careless search that answered with message texts would eat the
  # model's whole context window and leave the assistant useless for the rest of the conversation,
  # so this tool cannot return a body even if asked. Rows are served from the local Postgres index,
  # never from IMAP SEARCH.
  class SearchMessages < ApplicationTool
    tool_name "search_messages"
    title "Search messages"
    description <<~TEXT.squish
      Search the headers of your own indexed mail. Returns one compact row per message - id,
      account, folder, date, sender, subject, and the names and sizes of any attachments - and
      never returns message bodies. To read the text of one message, call get_message with the
      id from a row here. The number of rows is capped: when the answer says "truncated": true
      there are more matches, so narrow the query, the date range or the folder rather than
      asking for a bigger limit.
    TEXT

    input_schema(
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Words to look for in the subject, the sender and the recipients. Case and diacritics are ignored; every word has to match."
        },
        account_id: {
          type: "integer",
          description: "Id from list_mail_accounts. Omit to search every account you have connected."
        },
        folder: {
          type: "string",
          description: "Folder name, for example INBOX. Omit to search every folder."
        },
        since: {
          type: "string",
          format: "date",
          description: "Only messages sent on or after this date (YYYY-MM-DD)."
        },
        until: {
          type: "string",
          format: "date",
          description: "Only messages sent on or before this date (YYYY-MM-DD)."
        },
        limit: {
          type: "integer",
          description: "How many rows to return. Defaults to #{McpSearchGuard::DEFAULT_PAGE_SIZE}, never more than #{McpSearchGuard::MAX_PAGE_SIZE}."
        }
      },
      required: [ "query" ],
      additionalProperties: false
    )

    private
      def call
        return Hitch::MCP::Result.error("Give search_messages something to look for.") if query.blank?

        search_guard.admit!
        limit = McpSearchGuard.page_size(arguments["limit"])
        # One row past the limit only to tell the model whether narrowing is worth it.
        found = matches.limit(limit + 1).to_a
        truncated = found.size > limit
        rows = found.first(limit)

        rows_returned!(rows.size)
        search_guard.record_rows(rows.size)
        json_result(response(rows, truncated:))
      rescue Date::Error
        Hitch::MCP::Result.error("since and until have to be dates written as YYYY-MM-DD.")
      end

      def response(rows, truncated:)
        payload = { messages: rows.map { |message| row(message) }, returned: rows.size, truncated: }
        if truncated
          payload[:note] = "More messages match than were returned. Narrow the query, the date range or the folder."
        end
        payload
      end

      def row(message)
        {
          id: message.id,
          account_id: message.mail_account_id,
          folder: message.mail_folder.name,
          date: message.date&.iso8601,
          from: message.from_display,
          subject: message.subject,
          has_attachments: message.has_attachments
        }.tap do |row|
          row[:attachments] = attachments(message) if message.has_attachments
        end
      end

      def attachments(message)
        message.attachments.map { |attachment| attachment.slice("filename", "size") }
      end

      def matches
        relation = MailMessage.for_user(current_user).search(query)
        relation = relation.where(mail_account_id: mail_account.id) if account_scoped?
        relation = relation.joins(:mail_folder).where("lower(mail_folders.name) = lower(?)", folder) if folder.present?
        relation = relation.where(date: date_range) if date_range

        relation.preload(:mail_folder).order(Arel.sql("mail_messages.date DESC NULLS LAST, mail_messages.id DESC"))
      end

      def date_range
        return @date_range if defined?(@date_range)

        from = date_argument("since")&.beginning_of_day
        to = date_argument("until")&.end_of_day
        @date_range =
          if from && to then from..to
          elsif from then from..
          elsif to then ..to
          end
      end

      def date_argument(name)
        value = arguments[name]
        Date.parse(value.to_s).in_time_zone if value.present?
      end

      def query
        arguments["query"].to_s.strip
      end

      def folder
        arguments["folder"].to_s.strip
      end

      def account_scoped?
        arguments["account_id"].present?
      end

      # A search that names an account is budgeted against that account, as McpSearchGuard is
      # written for; one that spans every account the caller has is budgeted against the caller.
      def search_guard
        @search_guard ||= McpSearchGuard.new(account_scoped? ? mail_account : current_user)
      end
  end
end
