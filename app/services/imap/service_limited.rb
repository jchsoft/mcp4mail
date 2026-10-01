module Imap
  # The server is refusing because of a usage limit, not because anything is wrong with the
  # mailbox. Gmail caps IMAP at about 15 simultaneous connections per account and at a daily
  # download quota; over either it answers NO or BYE with "[ALERT] Too many simultaneous
  # connections" or "Account exceeded command or bandwidth limits". It clears by itself, so
  # callers retry later instead of treating the account as broken.
  class ServiceLimited < StandardError
    RESPONSES = Regexp.union(
      /too many simultaneous connections/i,
      /exceeded command or bandwidth limits/i,
      /bandwidth limit/i
    )
    LIMIT_CODES = %w[THROTTLED].freeze

    def self.limit?(error)
      return false unless error.is_a?(Net::IMAP::ResponseError)

      error.message.match?(RESPONSES) || LIMIT_CODES.include?(error.response.data.try(:code)&.name.to_s.upcase)
    end

    # The limit behind +error+ as a ServiceLimited, or nil. Follows the cause chain, because a
    # service that turns a refused FETCH into its own MessageGone still carries the NO as cause.
    def self.from(error)
      seen = []
      while error && !seen.include?(error)
        return new(error.message) if limit?(error)

        seen << error
        error = error.cause
      end
    end
  end
end
