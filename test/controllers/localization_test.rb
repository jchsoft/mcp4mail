require "test_helper"

class LocalizationTest < ActionDispatch::IntegrationTest
  test "defaults to English" do
    get new_session_path
    assert_select "html[lang=en]"
    assert_select "h1", "Sign in"
  end

  test "follows Accept-Language" do
    get new_session_path, headers: { "Accept-Language" => "cs-CZ,cs;q=0.9,en;q=0.8" }
    assert_select "h1", "Přihlášení"
  end

  test "an explicit choice sticks for the session and beats Accept-Language" do
    get root_path(locale: "cs")
    assert_select "html[lang=cs]"

    get new_session_path, headers: { "Accept-Language" => "en" }
    assert_select "h1", "Přihlášení"
  end

  test "ignores unsupported locales" do
    get new_session_path(locale: "de"), headers: { "Accept-Language" => "de-DE" }
    assert_select "html[lang=en]"
  end
end
