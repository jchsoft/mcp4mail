require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home page renders" do
    get root_url

    assert_response :success
    assert_select "h1", "mcp4mail"
  end

  test "home page has favicon links and Open Graph / Twitter meta tags" do
    get root_url

    assert_response :success
    assert_select "link[rel=icon][href='/favicon.ico']"
    assert_select "link[rel=icon][href='/icon.svg'][type='image/svg+xml']"
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png']"

    assert_select "meta[property='og:title']"
    assert_select "meta[property='og:description']"
    assert_select "meta[property='og:image'][content=?]", "#{root_url}og-image.png"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='twitter:image'][content=?]", "#{root_url}og-image.png"
  end
end
