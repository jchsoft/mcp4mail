# Provider setup guides on the public site: /guides lists them, /guides/:provider
# shows one. The content lives in Markdown files, see Guide.
class GuidesController < ApplicationController
  allow_unauthenticated_access

  layout "public"

  def index
    @guides = Guide.all
  end

  # An unknown provider raises RecordNotFound, which Rails answers with 404.
  def show
    @guide = Guide.find(params[:provider])
  end
end
