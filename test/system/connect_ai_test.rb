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
