xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [ root_url, guides_url, *@guides.map { |guide| guide_url(guide) } ].each do |url|
    xml.url { xml.loc url }
  end
end
