# /sitemap.xml: the public pages worth indexing — the landing page, the guides
# index and every guide.
class SitemapsController < ApplicationController
  allow_unauthenticated_access

  def show
    @guides = Guide.all
  end
end
