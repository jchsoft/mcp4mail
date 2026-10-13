# frozen_string_literal: true

# A successful MCP tool call carries its data twice, as structuredContent and as the same JSON
# in the text block. Hitch validates structuredContent against the tool's outputSchema while it
# builds the response, so this only has to check the two copies agree.
module StructuredResultTestHelper
  def assert_structured_matches_text(result)
    return if result["isError"]

    assert_kind_of Hash, result["structuredContent"]
    assert_equal result["structuredContent"], JSON.parse(result.dig("content", 0, "text"))
  end
end
