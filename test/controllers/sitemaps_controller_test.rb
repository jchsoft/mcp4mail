require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "lists the landing page, the guides index and every guide as XML, without signing in" do
    get sitemap_url

    assert_response :success
    assert_equal "application/xml", response.media_type
    locs = Nokogiri::XML(response.body).remove_namespaces!.css("url > loc").map(&:text)
    assert_includes locs, root_url
    assert_includes locs, guides_url
    Guide.all.each { |guide| assert_includes locs, guide_url(guide) }
  end

  test "is served the same in cs and en" do
    get sitemap_url(locale: :cs)
    cs = response.body
    get sitemap_url(locale: :en)

    assert_response :success
    assert_equal cs, response.body
  end
end
