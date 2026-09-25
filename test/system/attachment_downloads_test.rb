require "application_system_test_case"

# The download link get_attachment hands out, opened in a real browser. The token is the
# whole credential, so no test here signs in.
#
# Firefox is given a download directory and told to save PDFs there without asking, so a
# valid token is asserted by the file that lands on disk. A refusal is asserted by the
# status of the response Firefox navigated to and by that directory staying empty: the
# refused URL renders an empty page and no file.
class AttachmentDownloadsTest < ApplicationSystemTestCase
  # The download dir lives on the worker process, because Firefox's `browser.download.dir`
  # is set when the driver starts and reused across every test in the class. It is named
  # after the worker's pid when first asked for, inside the worker: a path fixed at class
  # load would be the parent's pid, shared by every parallel worker, and one worker's setup
  # would wipe the file another worker's Firefox had just saved. The path is created before
  # the driver hands it to Firefox, and cleared (not removed) between tests so the directory
  # itself never disappears mid-run - on macOS an open file handle on a child of it makes
  # `rm_rf` leave a phantom entry behind, and `mkdir_p` then refuses to recreate the path
  # with EEXIST.
  def self.download_dir
    Rails.root.join("tmp/downloads/system-#{Process.pid}").to_s.tap { |dir| FileUtils.mkdir_p(dir) }
  end

  # Its own driver name: under the shared :selenium name Capybara would reuse whichever
  # browser an earlier test already started, one without these preferences.
  driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ],
    options: { name: :headless_firefox_downloads } do |options|
    options.add_preference("intl.accept_languages", "en")
    options.add_preference("browser.download.folderList", 2)
    options.add_preference("browser.download.dir", download_dir)
    options.add_preference("browser.download.useDownloadDir", true)
    options.add_preference("browser.download.always_ask_before_handling_new_types", false)
    options.add_preference("browser.helperApps.neverAsk.saveToDisk", "application/pdf")
    # Otherwise Firefox opens the PDF in its built-in viewer instead of saving it.
    options.add_preference("pdfjs.disabled", true)
  end

  setup do
    @user = users(:one)
    FileUtils.rm_rf(Dir.glob("#{download_dir}/*"))
  end

  teardown do
    @server&.stop
    FileUtils.rm_rf(Dir.glob("#{download_dir}/*"))
  end

  test "a valid token downloads the attachment's bytes under its filename" do
    message = index_message_on_fake_server(content: "pdf-bytes", filename: "faktura.pdf")
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)

    # A download never finishes loading a page, so a plain `visit` would sit on the page
    # load until Selenium's read timeout. Following a link from a page leaves nothing to wait on.
    visit root_url
    page.execute_script("window.location.href = arguments[0]", attachment_download_url(token:))

    downloaded = File.join(download_dir, "faktura.pdf")
    # Firefox creates an empty placeholder under the final name before the bytes arrive,
    # so the file only counts as saved once it has content and the .part file is gone.
    saved = wait_until { File.size?(downloaded) && !File.exist?("#{downloaded}.part") }
    assert saved, "faktura.pdf was never saved"
    assert_equal "pdf-bytes", File.read(downloaded).strip
  end

  test "a token with a tampered signature is refused" do
    message = index_message_on_fake_server(content: "pdf-bytes", filename: "faktura.pdf")
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)
    tampered = token.sub(/.\z/) { |last| last == "a" ? "b" : "a" }

    visit attachment_download_url(token: tampered)

    assert_refused 404
  end

  test "an expired token is refused" do
    message = index_message_on_fake_server(content: "pdf-bytes", filename: "faktura.pdf")
    token = travel_to(AttachmentDownloadToken::EXPIRES_IN.ago - 1.minute) do
      AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)
    end

    visit attachment_download_url(token:)

    assert_refused 404
  end

  test "a token for another user's message is refused" do
    folder = mail_accounts(:personal).mail_folders.create!(name: "INBOX", uidvalidity: 1)
    message = mail_accounts(:personal).mail_messages.create!(
      mail_folder: folder, uidvalidity: 1, uid: 1, subject: "Not yours", from_address: "sender@example.com",
      has_attachments: true, attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 9 } ],
      search_text: "not yours"
    )
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)

    visit attachment_download_url(token:)

    assert_refused 404
  end

  test "a message whose folder UIDVALIDITY changed is reported gone" do
    message = index_message_on_fake_server(content: "pdf-bytes", filename: "faktura.pdf")
    @mailboxes["INBOX"][:uidvalidity] = 999
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)

    visit attachment_download_url(token:)

    assert_refused 410
  end

  private
    def download_dir = self.class.download_dir

    def index_message_on_fake_server(content:, filename:)
      @mailboxes = { "INBOX" => { uidvalidity: 1, messages: [ { uid: 1, body: multipart_body(content:, filename:) } ] } }
      @server = FakeImapServer.new(mailboxes: @mailboxes).start
      account = @user.mail_accounts.create!(
        host: "127.0.0.1", port: @server.port, ssl: false, username: "bob", password: "fixture-app-password"
      )
      folder = account.mail_folders.create!(name: "INBOX", uidvalidity: 1)
      account.mail_messages.create!(
        mail_folder: folder, uidvalidity: 1, uid: 1, subject: "Invoice", from_address: "sender@example.com",
        has_attachments: true, attachments: [ { "filename" => filename, "content_type" => "application/pdf", "size" => content.bytesize } ],
        search_text: "invoice"
      )
    end

    # The refusal is a bare status, so the page Firefox shows is empty. Its status comes
    # from the Navigation Timing entry of the page Firefox actually landed on.
    def assert_refused(status)
      assert_equal status, page.evaluate_script("performance.getEntriesByType('navigation')[0].responseStatus")
      assert_equal "", page.text.strip
      assert_empty Dir.children(download_dir), "a refused token must not save a file"
    end

    def wait_until(timeout: Capybara.default_max_wait_time)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until (result = yield)
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.1
      end
      result
    end

    def multipart_body(content:, filename:)
      <<~RAW.b
        Content-Type: multipart/mixed; boundary="BOUNDARY123"

        --BOUNDARY123
        Content-Type: text/plain; charset=UTF-8

        See attached.
        --BOUNDARY123
        Content-Type: application/pdf
        Content-Disposition: attachment; filename="#{filename}"
        Content-Transfer-Encoding: 7bit

        #{content}
        --BOUNDARY123--
      RAW
    end
end
