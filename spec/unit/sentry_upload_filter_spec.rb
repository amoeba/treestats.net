require_relative "../spec_helper"
require "sentry-ruby"
require_relative "../../lib/sentry_upload_filter"

describe SentryUploadFilter do
  def event_for(path, method: "POST", body: '{"name":"Example","key":"credential"}')
    config = Sentry::Configuration.new
    config.send_default_pii = true
    event = Sentry::ErrorEvent.new(configuration: config)
    event.rack_env = Rack::MockRequest.env_for(
      "https://example.test#{path}?token=credential&page=2",
      method: method,
      input: body,
      **{
        "CONTENT_TYPE" => "application/json",
        "HTTP_X_TREESTATS_SERVER_TOKEN" => "credential",
        "HTTP_COOKIE" => "session=credential"
      }
    )
    event
  end

  it "keeps character data while removing credentials from upload requests" do
    ["/", "/characters", "/characters/"].each do |path|
      event = event_for(path)
      assert_same event, SentryUploadFilter.filter(event, {})

      request = event.to_json_compatible.fetch("request")
      assert_equal({"name" => "Example"}, request["data"])
      assert_nil request["cookies"]
      assert_nil request["query_string"]
      refute_includes request["headers"].to_s, "credential"
    end
  end

  it "does not forward unparseable upload bodies" do
    event = event_for("/", body: "credential")
    SentryUploadFilter.filter(event, {})

    assert_nil event.request.data
  end

  it "removes upload tokens from other requests without stripping their context" do
    event = event_for("/other")
    SentryUploadFilter.filter(event, {})

    refute_includes event.request.headers.to_s, "credential"
    assert_equal({"token" => "[Filtered]", "page" => "2"}, event.request.query_string)
  end

  it "accepts events without a request" do
    event = Sentry::ErrorEvent.new(configuration: Sentry::Configuration.new)
    assert_same event, SentryUploadFilter.filter(event, {})
  end
end
