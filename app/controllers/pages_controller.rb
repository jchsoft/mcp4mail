class PagesController < ApplicationController
  allow_unauthenticated_access

  # The landing page is the public face: marketing header and footer, not the
  # signed-in application chrome.
  layout "public"

  def home
  end
end
