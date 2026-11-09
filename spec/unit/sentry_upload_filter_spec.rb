require_relative "../spec_helper"
require "sentry-ruby"
require_relative "../../lib/sentry_upload_filter"

describe SentryUploadFilter do
  def event_for(path, method: "POST")
    config = Sentry::Configuration.new
    config.send_default_pii = true
    event = Sentry::ErrorEvent.new(configuration: config)
    event.rack_env = Rack::MockRequest.env_for(
      "https://example.test#{path}?private=query",
      method: method,
      input: '{"name":"private-character"}',
      **{
        "CONTENT_TYPE" => "application/json",
        "HTTP_X_TREESTATS_SERVER_TOKEN" => "private-token",
        "HTTP_COOKIE" => "session=private-cookie",
        "REMOTE_ADDR" => "192.0.2.1"
      }
    )
    event
  end

  it "removes request data from both upload routes" do
    ["/", "/characters", "/characters/"].each do |path|
      event = event_for(path)
      assert_includes event.to_json_compatible.to_s, "private-token"

      assert_same event, SentryUploadFilter.filter(event, {})

      request = event.to_json_compatible.fetch("request")
      %w[data headers cookies query_string env].each { |key| assert_nil request[key] }
      refute_includes event.to_json_compatible.to_s, "private-"
      refute event.user.key?(:ip_address)
    end
  end

  it "removes upload tokens from other requests without stripping their context" do
    event = event_for("/other")
    SentryUploadFilter.filter(event, {})
    request = event.to_json_compatible.fetch("request")

    refute_includes request.fetch("headers").to_s, "private-token"
    assert_equal "private=query", request["query_string"]
  end

  it "preserves request context for GET requests to the character listing" do
    event = event_for("/characters", method: "GET")
    SentryUploadFilter.filter(event, {})

    assert_equal "private=query", event.request.query_string
  end

  it "accepts events without a request" do
    event = Sentry::ErrorEvent.new(configuration: Sentry::Configuration.new)
    assert_same event, SentryUploadFilter.filter(event, {})
  end
end
