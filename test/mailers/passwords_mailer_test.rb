require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset goes to the user and carries the reset link" do
    user = users(:one)
    mail = PasswordsMailer.reset(user)

    assert_equal [ user.email_address ], mail.to
    assert_equal "Reset your password", mail.subject

    [ mail.html_part, mail.text_part ].each do |part|
      assert_includes part.body.to_s, "http://example.com/passwords/#{user.password_reset_token}/edit"
    end
  end
end
