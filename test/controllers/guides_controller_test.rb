require "test_helper"

class GuidesControllerTest < ActionDispatch::IntegrationTest
  test "index lists the guides as cards linking to each one" do
    get guides_url

    assert_response :success
    assert_select "h1", "Set up your mailbox"
    assert_select "a[href=?] h2", guide_path("seznam"), "Seznam.cz (Email.cz)"
    assert_select "link[rel=canonical][href=?]", guides_url
  end

  test "a guide renders its Markdown body, facts and the connect block" do
    get guide_url("seznam")

    assert_response :success
    assert_select "title", "Seznam.cz (Email.cz) over IMAP · mcp4mail guide"
    assert_select "h1", "Seznam.cz (Email.cz)"
    assert_select "code", "imap.seznam.cz"
    assert_select ".guide-prose h2", /Switch on IMAP in Seznam/
    assert_select ".guide-prose table td code", "993"
    assert_select "section h2", "Now connect it in mcp4mail"
    assert_select "section a[href=?]", new_mail_account_path, "Connect a mailbox"
    assert_select "link[rel=canonical][href=?]", guide_url("seznam")
  end

  test "an unknown provider is a 404" do
    get guide_url("nosuchprovider")

    assert_response :not_found
  end

  test "the provider parameter never reaches the file system" do
    get "/guides/..%2F..%2Fconfig%2Fdatabase"

    assert_response :not_found
  end

  test "guide chrome follows the locale" do
    get guide_url("seznam", locale: "cs")

    assert_select "html[lang=cs]"
    assert_select "section h2", "Teď ji připojte v mcp4mail"
  end

  test "the sitemap lists the landing page, the guides index and every guide" do
    get sitemap_url

    assert_response :success
    assert_equal "application/xml", response.media_type
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    assert_includes locs, root_url
    assert_includes locs, guides_url
    assert_includes locs, guide_url("seznam")
  end
end
