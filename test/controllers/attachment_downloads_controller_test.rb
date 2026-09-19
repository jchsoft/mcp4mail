require "test_helper"

class AttachmentDownloadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "serves the attachment's decoded bytes for a valid token" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: multipart_body(content: "pdf-bytes", filename: "faktura.pdf"),
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 9 } ])
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)

    get attachment_download_url(token:)

    assert_response :success
    assert_equal "pdf-bytes", response.body
    assert_equal "application/pdf", response.media_type
    assert_match(/faktura\.pdf/, response.headers["Content-Disposition"])
  ensure
    server&.stop
  end

  test "refuses a token whose signature does not verify" do
    get attachment_download_url(token: "not-a-real-token")

    assert_response :not_found
  end

  test "refuses a token for a message that does not belong to that user" do
    message = index_message(mail_accounts(:personal), uid: 1, subject: "Not yours",
      attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 9 } ])
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)

    get attachment_download_url(token:)

    assert_response :not_found
  end

  test "reports gone when the folder's UIDVALIDITY has since changed" do
    server, account = start_fake_account
    message = index_body_message(account, uid: 1, body: multipart_body(content: "pdf-bytes", filename: "faktura.pdf"),
      uidvalidity: 1, attachments: [ { "filename" => "faktura.pdf", "content_type" => "application/pdf", "size" => 9 } ])
    @fake_mailboxes["INBOX"][:uidvalidity] = 999
    token = AttachmentDownloadToken.generate(user: @user, message:, attachment_index: 0)

    get attachment_download_url(token:)

    assert_response :gone
  ensure
    server&.stop
  end

  private
    def start_fake_account
      @fake_mailboxes = { "INBOX" => { uidvalidity: 1, messages: [] } }
      server = FakeImapServer.new(mailboxes: @fake_mailboxes).start
      account = @user.mail_accounts.create!(
        host: "127.0.0.1", port: server.port, ssl: false, username: "bob", password: "fixture-app-password"
      )
      [ server, account ]
    end

    def index_body_message(account, uid:, body:, uidvalidity: 1, subject: "Subject", attachments: [])
      folder = account.mail_folders.find_or_create_by!(name: "INBOX") { |new_folder| new_folder.uidvalidity = uidvalidity }
      message = account.mail_messages.create!(
        mail_folder: folder, uidvalidity:, uid:, subject:, from_address: "sender@example.com",
        has_attachments: attachments.any?, attachments:,
        search_text: MailMessage.build_search_text(subject:, from_name: nil, from_address: "sender@example.com", to_addresses: [], cc_addresses: [])
      )
      @fake_mailboxes["INBOX"][:messages] << { uid:, body: }
      message
    end

    def index_message(account, uid:, subject:, attachments: [])
      folder = account.mail_folders.find_or_create_by!(name: "INBOX") { |new_folder| new_folder.uidvalidity = 1 }
      account.mail_messages.create!(
        mail_folder: folder, uidvalidity: folder.uidvalidity, uid:, subject:, from_address: "sender@example.com",
        has_attachments: attachments.any?, attachments:,
        search_text: MailMessage.build_search_text(subject:, from_name: nil, from_address: "sender@example.com", to_addresses: [], cc_addresses: [])
      )
    end

    def multipart_body(content:, filename:, content_type: "application/pdf")
      <<~RAW.b
        Content-Type: multipart/mixed; boundary="BOUNDARY123"

        --BOUNDARY123
        Content-Type: text/plain; charset=UTF-8

        See attached.
        --BOUNDARY123
        Content-Type: #{content_type}
        Content-Disposition: attachment; filename="#{filename}"
        Content-Transfer-Encoding: 7bit

        #{content}
        --BOUNDARY123--
      RAW
    end
end
