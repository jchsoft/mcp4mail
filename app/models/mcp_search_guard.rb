# Keeps a runaway agent loop from walking a whole mailbox through the search tool: every page is
# capped, and each account has a budget of searches and of returned rows per window.
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

  def initialize(mail_account)
    @mail_account = mail_account
  end

  def admit!
    raise Exhausted, "Search row budget for this account is used up; try again within the hour." if ROWS.exhausted?(@mail_account)
    raise Exhausted, "Too many searches on this account; try again in a few minutes." unless SEARCHES.admit?(@mail_account)
  end

  def record_rows(count)
    ROWS.consume(@mail_account, count)
  end
end
