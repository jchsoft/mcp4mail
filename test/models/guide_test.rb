require "test_helper"

class GuideTest < ActiveSupport::TestCase
  test "reads the front-matter of every guide file" do
    guide = Guide.find("seznam")

    assert_equal "Seznam.cz (Email.cz)", guide.title
    assert_equal "imap.seznam.cz", guide.imap_host
    assert_not guide.needs_app_password?
    assert_equal "seznam", guide.to_param
    assert_match "<h2", guide.html
  end

  test "every guide has a unique provider, a summary and the IMAP front-matter" do
    guides = Guide.all

    assert_equal guides.map(&:provider).uniq, guides.map(&:provider)
    guides.each do |guide|
      assert guide.summary.present?, "#{guide.provider} has no summary"
      assert_match(/\A[a-zA-Z0-9.-]+\z/, guide.imap_host, "#{guide.provider} has no imap_host")
      assert_includes [ true, false ], guide.needs_app_password?, "#{guide.provider} has no needs_app_password"
    end
  end

  test "all is sorted by the order field" do
    orders = Guide.all.map(&:order)

    assert_equal orders.sort, orders
  end

  test "an unknown provider raises RecordNotFound" do
    assert_raises(ActiveRecord::RecordNotFound) { Guide.find("nope") }
  end

  test "a file without front-matter is rejected" do
    Tempfile.create([ "guide", ".md" ]) do |file|
      file.write("# no front-matter\n")
      file.flush
      assert_raises(ArgumentError) { Guide.from_file(file.path) }
    end
  end
end
