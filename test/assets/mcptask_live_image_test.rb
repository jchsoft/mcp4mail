require "test_helper"

# The "How it's built" section shows a real capture of mcptask.online/live. The file
# is a build artifact of task #12697, so these guard the properties that section
# relies on: the 3:2 slot it fills, a weight that is fine to ship, and the partial
# that renders it without shifting the layout as it loads.
class McptaskLiveImageTest < ActiveSupport::TestCase
  IMAGE = Rails.root.join("app/assets/images/mcptask-live.webp")
  PARTIAL = Rails.root.join("app/views/pages/_built_live_image.html.erb")
  MAX_BYTES = 200 * 1024

  test "the screenshot ships as a WebP" do
    assert IMAGE.exist?, "#{IMAGE.relative_path_from(Rails.root)} is missing"
    assert_equal "RIFF", IMAGE.binread(4)
    assert_equal "WEBP", IMAGE.binread(4, 8)
  end

  test "the screenshot stays under 200 kB" do
    assert_operator IMAGE.size, :<=, MAX_BYTES,
      "the screenshot is #{IMAGE.size} bytes, over the #{MAX_BYTES} byte budget"
  end

  test "the screenshot is 3:2, the aspect ratio of the slot it fills" do
    width, height = webp_dimensions(IMAGE)

    assert_equal 3.0 / 2, width.to_f / height, "the screenshot is #{width}x#{height}, not 3:2"
  end

  test "the partial declares the dimensions of the file it renders" do
    width, height = webp_dimensions(IMAGE)
    markup = PARTIAL.read

    assert_match(/width:\s*#{width}\b/, markup)
    assert_match(/height:\s*#{height}\b/, markup)
  end

  test "the partial defers loading and points at the capture recipe" do
    markup = PARTIAL.read

    assert_match(/loading:\s*"lazy"/, markup)
    assert_match(/decoding:\s*"async"/, markup)
    assert_match(/12697/, markup, "the partial should say where the capture recipe is written down")
  end

  test "the alt text describes the picture rather than the file" do
    I18n.available_locales.each do |locale|
      alt = I18n.t("pages.home.built.image_alt", locale: locale, raise: true)

      assert_operator alt.length, :>, 40, "#{locale}.yml: the alt text is too short to describe the picture"
      assert_no_match(/^(screenshot|snímek)\b/i, alt,
        "#{locale}.yml: the alt text describes the file, not what the picture shows")
    end
  end

  private
    # A lossy WebP is a RIFF container holding one "VP8 " chunk, whose keyframe header
    # carries the dimensions as two 14-bit values right after the 9d 01 2a start code.
    def webp_dimensions(path)
      header = path.binread(30)
      assert_equal "VP8 ", header[12, 4], "expected a lossy WebP"
      assert_equal "\x9D\x01\x2A".b, header[23, 3], "expected a VP8 keyframe start code"

      header[26, 4].unpack("v2").map { |value| value & 0x3FFF }
    end
end
