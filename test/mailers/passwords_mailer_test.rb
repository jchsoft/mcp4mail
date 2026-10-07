require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset goes to the user and carries the reset link" do
    user = users(:one)
    mail = PasswordsMailer.reset(user)

    assert_equal [ user.email_address ], mail.to
    assert_equal "Reset your password", mail.subject

    [ mail.html_part, mail.text_part ].each do |part|
      assert_match %r{http://example.com/passwords/[\w=-]+--\h+/edit}, part.body.to_s
    end
  end
end
