require_relative "../story_helper"

describe "ServerInfoStandardStory" do
  it "serves the published server information schema" do
    get "/schemas/asherons-call-server/v1/schema.json"
    assert_equal 200, last_response.status
    assert_equal "application/json", last_response.headers["Content-Type"]

    schema = JSON.parse(last_response.body)
    assert_equal true, schema["additionalProperties"]
    assert_equal "https://treestats.net/schemas/asherons-call-server/v1/schema.json", schema["$id"]
    assert_equal "object", schema["type"]
    refute schema.key?("required")
    refute schema.key?("dependentRequired")
    refute schema.dig("properties", "population").key?("required")
    refute schema.dig("properties", "emulator").key?("required")
    assert_equal 1, schema.dig("properties", "version", "const")
    assert_equal %w[count updated_at], schema.dig("properties", "population", "properties").keys.sort
    assert_equal %w[dat_iterations database_version name server_version],
      schema.dig("properties", "emulator", "properties").keys.sort
    assert_equal "integer", schema.dig("properties", "emulator", "properties", "dat_iterations", "additionalProperties", "type")
    assert_equal 0, schema.dig("properties", "emulator", "properties", "dat_iterations", "additionalProperties", "minimum")
  end
end
