require "application_system_test_case"

class ConnectAiTest < ApplicationSystemTestCase
  test "the segmented control shows one client's instructions at a time" do
    visit connect_ai_url

    assert_selector "[role=tab]", count: 4
    assert_selector "#client-claude", text: "Add custom connector"
    assert_no_selector "#client-cursor"
    screenshot!("connect_ai-claude-en")

    click_on "Cursor"

    assert_selector "#client-cursor", text: "Tools & MCP"
    assert_no_selector "#client-claude"
    assert_selector "#tab-cursor[aria-selected=true]"
    assert_selector "#tab-claude[aria-selected=false]"
    screenshot!("connect_ai-cursor-en")

    click_on "ChatGPT"
    screenshot!("connect_ai-chatgpt-en")

    click_on "Other MCP client"
    screenshot!("connect_ai-other-en")
  end

  test "arrow keys, Home and End move the roving tabindex and selection between tabs" do
    visit connect_ai_url

    assert_selector "#tab-claude[aria-selected=true][tabindex='0']"
    assert_selector "#tab-chatgpt[aria-selected=false][tabindex='-1']"

    find("#tab-claude").send_keys(:arrow_right)
    assert_selector "#tab-chatgpt[aria-selected=true][tabindex='0']"
    assert_selector "#tab-claude[aria-selected=false][tabindex='-1']"
    assert_selector "#client-chatgpt"
    assert_no_selector "#client-claude"
    assert_equal "tab-chatgpt", evaluate_script("document.activeElement.id")

    find("#tab-chatgpt").send_keys(:arrow_left)
    assert_selector "#tab-claude[aria-selected=true][tabindex='0']"
    assert_equal "tab-claude", evaluate_script("document.activeElement.id")

    find("#tab-claude").send_keys(:end)
    assert_selector "#tab-other[aria-selected=true][tabindex='0']"
    assert_selector "#client-other"
    assert_equal "tab-other", evaluate_script("document.activeElement.id")
    screenshot!("connect_ai-keyboard-end-en")

    find("#tab-other").send_keys(:home)
    assert_selector "#tab-claude[aria-selected=true][tabindex='0']"
    assert_equal "tab-claude", evaluate_script("document.activeElement.id")
  end

  test "the no-mailbox reminder appears for a signed-in user with no mailboxes yet" do
    visit new_registration_url
    fill_in "Email address", with: "fresh@example.com"
    fill_in "Password", with: "long-enough", match: :prefer_exact
    fill_in "Password confirmation", with: "long-enough"
    click_on "Create account"

    visit connect_ai_url
    assert_selector "#no-mailbox", text: "You have no mailbox yet"
    screenshot!("connect_ai-no-mailbox-en")

    click_on "Add a mailbox."
    assert_selector "h1", text: "Add a mailbox"
  end

  test "the Copy button puts the server URL on the clipboard and says so" do
    visit connect_ai_url

    # Firefox only hands readText to a page with the clipboard-read permission,
    # which Selenium cannot grant, so the write itself is what gets recorded.
    page.execute_script(<<~JS)
      window.copied = null
      navigator.clipboard.writeText = text => { window.copied = text; return Promise.resolve() }
    JS

    click_on "Copy"

    assert_selector "button", exact_text: "Copied"
    screenshot!("connect_ai-copied-en")
    assert_equal page.evaluate_script("window.copied"), find("#server-url").value
    assert_selector "button", exact_text: "Copy", wait: 5
  end
end
