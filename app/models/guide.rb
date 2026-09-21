# A provider setup guide on the public site. Each guide is a Markdown file under
# app/views/guides/content/<provider>.md with a YAML front-matter block, so a new
# provider is a new file and nothing else:
#
#   ---
#   title: Seznam.cz
#   provider: seznam
#   summary: Switch on IMAP in Seznam settings, then sign in with the full address.
#   imap_host: imap.seznam.cz
#   needs_app_password: false
#   order: 10
#   ---
#
# The provider key comes from the front-matter, not the file name, and lookups
# go through that list — a request parameter never becomes a path.
class Guide
  CONTENT_DIR = Rails.root.join("app/views/guides/content")
  FRONT_MATTER = /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m

  attr_reader :provider, :title, :summary, :imap_host, :order, :body

  def self.all
    Dir[CONTENT_DIR.join("*.md")].map { |path| from_file(path) }.sort_by { |guide| [ guide.order, guide.title ] }
  end

  def self.find(provider)
    all.find { |guide| guide.provider == provider.to_s } ||
      raise(ActiveRecord::RecordNotFound, "No guide for provider #{provider.inspect}")
  end

  def self.from_file(path)
    match = FRONT_MATTER.match(File.read(path)) or raise ArgumentError, "#{path} has no front-matter"
    new(**YAML.safe_load(match[1]).symbolize_keys, body: match[2])
  end

  def initialize(title:, provider:, body:, summary: nil, imap_host: nil, needs_app_password: false, order: 100)
    @title = title
    @provider = provider.to_s
    @summary = summary
    @imap_host = imap_host
    @needs_app_password = needs_app_password
    @order = order
    @body = body
  end

  def needs_app_password?
    @needs_app_password
  end

  def to_param
    provider
  end

  # The files are ours, checked into the repository, so raw HTML in them is
  # allowed; nothing a visitor sends reaches the renderer.
  def html
    self.class.renderer.render(body).html_safe
  end

  def self.renderer
    @renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(with_toc_data: true),
      tables: true, fenced_code_blocks: true, autolink: true, no_intra_emphasis: true
    )
  end
end
