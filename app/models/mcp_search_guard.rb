# Keeps a runaway agent loop from walking a whole mailbox through the search tool: every page is
# capped, and each subject - a mail account, or the caller when a search spans all of their
# accounts - has a budget of searches and of returned rows per window.
class McpSearchGuard
  class Exhausted < StandardError; end

  DEFAULT_PAGE_SIZE = 20
  MAX_PAGE_SIZE = 50
  SEARCHES = McpQuota.new("search-calls", to: 60, within: 10.minutes)
  ROWS = McpQuota.new("search-rows", to: 1_000, within: 1.hour)

  def self.page_size(requested)
    return DEFAULT_PAGE_SIZE if requested.nil?

    requested.to_i.clamp(1, MAX_PAGE_SIZE)
  end

  def initialize(subject)
    @subject = subject
  end

  def admit!
    raise Exhausted, "Search row budget is used up; try again within the hour." if ROWS.exhausted?(@subject)
    raise Exhausted, "Too many searches; try again in a few minutes." unless SEARCHES.admit?(@subject)
  end

  def record_rows(count)
    ROWS.consume(@subject, count)
  end
end
