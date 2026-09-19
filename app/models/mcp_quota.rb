# Fixed-window counter for limits Hitch does not cover. It counts through the same store Hitch's own
# admission uses, which production already requires to be shared across processes. A store that
# cannot count (null store in test) admits everything, as Hitch and Rails' own limiter do.
class McpQuota
  KEY_PREFIX = "mcp4mail:quota:v1"

  # Tests point this at a MemoryStore; nil means Hitch's resolved rate limit store.
  cattr_accessor :store_override

  attr_reader :name, :to, :within

  def initialize(name, to:, within:)
    @name = name
    @to = to
    @within = within.to_i
  end

  # Counts one use and answers whether it still fits the window.
  def admit?(subject)
    count = consume(subject, 1)
    count.nil? || count <= to
  end

  # Adds amount to the window and returns the new total (nil when the store cannot count).
  def consume(subject, amount)
    self.class.store.increment(key_for(subject), amount, expires_in: within)
  end

  def exhausted?(subject)
    used = consume(subject, 0)
    !used.nil? && used >= to
  end

  def self.store
    store_override || Hitch.configuration.mcp.rate_limit_store
  end

  private
    def key_for(subject)
      window = Time.now.to_i / within
      "#{KEY_PREFIX}:#{name}:#{subject.class.base_class.name}:#{subject.id}:#{window}"
    end
end
