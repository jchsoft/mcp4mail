# frozen_string_literal: true

module McpTools
  # Base for every mcp4mail tool. A tool is read-only unless it says otherwise with write_tool,
  # and McpToolRegistry refuses any tool that declares neither. A write tool runs only against
  # a mailbox whose owner switched on "Allow the AI to make changes" (MailAccount#writable).
  #
  # Every call is scoped to the signed-in user's own MailAccount records, counted against a
  # per-user quota that spans all of their connected clients (Hitch already limits each
  # user + client pair), and written to McpAuditEvent.
  class ApplicationTool < Hitch::MCP::Tool
    READ_ONLY_ANNOTATIONS = {
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false
    }.freeze

    # What the model reads when it asks a read-only mailbox for a change: the one thing the
    # person has to do, not an error code.
    READ_ONLY_MAILBOX = "This mailbox is read-only. The owner can allow changes in mcp4mail under Mail accounts."

    USER_CALLS = McpQuota.new("tool-calls", to: 240, within: 1.minute)

    class << self
      def inherited(subclass)
        super
        subclass.annotations(**READ_ONLY_ANNOTATIONS)
      end

      # A human name for the tool. MCP clients show it instead of the wire name, and so
      # does the activity list on the mailboxes page - a person reads "Search messages",
      # not search_messages. annotations replaces the whole hash, so merge into it.
      def title(value = nil)
        return (annotations || {})[:title] if value.nil?

        annotations(**(annotations || {}), title: value)
      end

      def read_only?
        declared = annotations || {}
        declared[:read_only_hint] == true && declared[:destructive_hint] == false
      end

      # Declares a tool that changes the mailbox. Whether it can destroy anything is the
      # tool's own answer, so it has no default. Annotations set before this call (a title)
      # are kept.
      def write_tool(destructive:)
        raise ArgumentError, "destructive: must be true or false" unless destructive == true || destructive == false

        @write_tool = true
        annotations(**(annotations || {}), read_only_hint: false, destructive_hint: destructive, idempotent_hint: false)
      end

      def write_tool?
        @write_tool == true
      end

      def available_to?(context)
        context.principal.is_a?(User)
      end

      # An account id that is not the caller's is refused before any tool code runs.
      def authorize!(context, arguments:)
        return unless arguments.key?("account_id")
        return if context.principal.mail_accounts.exists?(id: arguments["account_id"])

        McpAuditEvent.record!(context:, tool_name:, outcome: "denied", mail_account_id: arguments["account_id"])
        raise Hitch::MCP::Forbidden
      end

      def perform(context, arguments:)
        new(context, arguments).invoke
      end
    end

    attr_reader :context, :arguments

    def initialize(context, arguments)
      @context = context
      @arguments = arguments
      @rows_returned = 0
    end

    def invoke
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      outcome = "error"

      if self.class.write_tool? && !mail_account.writable?
        outcome = "denied"
        return Hitch::MCP::Result.error(READ_ONLY_MAILBOX)
      end

      unless USER_CALLS.admit?(current_user)
        outcome = "rate_limited"
        return Hitch::MCP::Result.error("Rate limit exceeded; slow down and retry in a minute.")
      end

      result = call
      outcome = result.kind == :error ? "error" : "ok"
      result
    rescue McpSearchGuard::Exhausted => exhausted
      outcome = "search_limited"
      Hitch::MCP::Result.error(exhausted.message)
    ensure
      McpAuditEvent.record!(
        context:,
        tool_name: self.class.tool_name,
        outcome:,
        mail_account_id: @mail_account&.id || arguments["account_id"],
        rows_returned: @rows_returned,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      )
    end

    private
      def call
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end

      def current_user
        context.principal
      end

      def mail_accounts
        current_user.mail_accounts
      end

      # authorize! has already proven the id is the caller's; find stays scoped regardless.
      # A write tool whose account comes from something else (a message id) overrides this,
      # because the writable check before #call asks it which mailbox is about to change.
      def mail_account
        @mail_account ||= mail_accounts.find(arguments.fetch("account_id"))
      end

      def search_guard
        @search_guard ||= McpSearchGuard.new(mail_account)
      end

      def rows_returned!(count)
        @rows_returned = count
      end

      def json_result(value)
        Hitch::MCP::Result.text(JSON.generate(value))
      end

      def account_summary(account)
        account.slice(:id, :display_name, :host, :port, :ssl, :username, :default_folder, :writable)
      end
  end
end
