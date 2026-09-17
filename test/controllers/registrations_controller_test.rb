require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create signs the new user in and sends them to add a mailbox" do
    assert_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "New@Example.com", password: "long-enough", password_confirmation: "long-enough" } }
    end

    assert_redirected_to new_mail_account_path
    assert cookies[:session_id].present?
    assert_equal "new@example.com", User.last.email_address
  end

  test "create with a taken email address re-renders the form" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: users(:one).email_address, password: "long-enough", password_confirmation: "long-enough" } }
    end

    assert_response :unprocessable_entity
    assert_select "#errors", /Email address has already been taken/
  end

  test "create with mismatched passwords re-renders the form" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "new@example.com", password: "long-enough", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
  end
end
