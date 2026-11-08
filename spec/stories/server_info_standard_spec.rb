require_relative "../story_helper"

describe "ServerInfoStandardStory" do
  it "serves the published server information schema" do
    get "/schemas/asherons-call-server/v1/schema.json"
    assert_equal 200, last_response.status

    schema = JSON.parse(last_response.body)
    assert_equal "https://treestats.net/schemas/asherons-call-server/v1/schema.json", schema["$id"]
    assert_equal "object", schema["type"]
    assert_equal %w[count updated_at], schema.dig("properties", "population", "required").sort
  end
end
