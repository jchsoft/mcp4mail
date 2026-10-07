require "application_system_test_case"

# "Download my data" on the account page, in a real browser. Firefox is told to save JSON
# without asking, so a working export is asserted by the file that lands on disk.
class AccountExportTest < ApplicationSystemTestCase
  # Per worker pid, like AttachmentDownloadsTest: the driver reads it once per process.
  def self.download_dir
    Rails.root.join("tmp/downloads/export-#{Process.pid}").to_s.tap { |dir| FileUtils.mkdir_p(dir) }
  end

  driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ],
    options: { name: :headless_firefox_export_downloads } do |options|
    options.add_preference("intl.accept_languages", "en")
    options.add_preference("browser.download.folderList", 2)
    options.add_preference("browser.download.dir", download_dir)
    options.add_preference("browser.download.useDownloadDir", true)
    options.add_preference("browser.download.always_ask_before_handling_new_types", false)
    options.add_preference("browser.helperApps.neverAsk.saveToDisk", "application/json")
  end

  setup do
    @user = users(:one)
    FileUtils.rm_rf(Dir.glob("#{download_dir}/*"))
    visit new_session_url
    fill_in placeholder: "Enter your email address", with: @user.email_address
    fill_in placeholder: "Enter your password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end

  teardown { FileUtils.rm_rf(Dir.glob("#{download_dir}/*")) }

  test "Download my data saves the account as a JSON file" do
    visit account_url
    screenshot!("account-export-en")

    click_link "Download my data"

    downloaded = File.join(download_dir, AccountExport.filename(@user))
    saved = wait_until { File.size?(downloaded) && !File.exist?("#{downloaded}.part") }
    assert saved, "expected #{downloaded} to be saved"
    assert_equal @user.email_address, JSON.parse(File.read(downloaded)).dig("user", "email_address")
  end

  private
    def download_dir = self.class.download_dir

    def wait_until(timeout: Capybara.default_max_wait_time)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until (result = yield)
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.1
      end
      result
    end
end
