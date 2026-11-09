require_relative "../spec_helper"
require "open3"
require "rbconfig"
require "sentry-ruby"
require "sentry/transport/dummy_transport"
require_relative "../../lib/sentry_upload_filter"

describe UploadSampling do
  it "summarizes realistic plugin values without retaining identifying data" do
    payload = JSON.parse(File.read(File.expand_path("../../util/plugin/plugin_message.txt", __dir__)))
    summary = UploadSampling.summarize(payload)

    assert_equal "1", summary[:version]
    assert_equal "integer", summary[:fields]["level"][:type]
    assert_equal "positive:100_to_999", summary[:fields]["level"][:range]
    assert_equal "us_12h", summary[:birth_format]
    assert_equal %w[Specialized Trained Untrained Unusable], summary[:skills][:training]
    assert_equal %w[numeric], summary[:properties][:key_types]
    assert_equal %w[integer], summary[:titles][:item_types]
    refute_includes summary.to_s, payload["name"]
    refute_includes summary.to_s, payload["birth"]
    refute_includes summary.to_s, payload["key"]
  end

  it "does not copy arbitrary field names or values from nested objects" do
    payload = {
      "name" => "private-name", "server" => "private-server", "version" => "private-version",
      "attribs" => {"private-key" => {"name" => "private-attribute"}},
      "skills" => {"private-skill" => {"name" => "private-name", "training" => "private-training"}},
      "properties" => {"private-property" => "private-value"},
      "vassals" => [{"name" => "private-vassal"}], "private-field" => "private-value"
    }
    summary = UploadSampling.summarize(payload)

    assert_equal "other", summary[:version]
    assert_equal ["other"], summary[:skills][:training]
    assert_equal ["other"], summary[:properties][:key_types]
    assert summary[:attribs][:other_keys]
    refute_includes summary.to_s, "private"
  end

  it "bounds nested collection processing" do
    payload = {"skills" => (0..100).to_h { |i| [i.to_s, {"training" => "Trained"}] },
               "titles" => Array.new(101, 1)}
    summary = UploadSampling.summarize(payload)

    assert summary[:skills][:truncated]
    assert summary[:titles][:truncated]
  end

  it "sends only the sanitized summary through Sentry" do
    character = ["private", "character"].join("-")
    token = ["private", "token"].join("-")
    Sentry.init do |config|
      config.dsn = "http://public@example.invalid/1"
      config.transport.transport_class = Sentry::DummyTransport
      config.background_worker_threads = 0
      config.enabled_environments = ["test"]
      config.before_send = SentryUploadFilter.method(:filter)
    end
    env = Rack::MockRequest.env_for("https://example.test/", method: "POST",
      input: JSON.generate(name: character),
      **{"HTTP_X_TREESTATS_SERVER_TOKEN" => token})
    summary = UploadSampling.summarize({"name" => character, "server" => "example", "level" => 50})

    Sentry.with_scope do |scope|
      scope.set_rack_env(env)
      UploadSampling.capture(summary)
    end
    event = Sentry.get_current_client.transport.events.fetch(0).to_json_compatible

    assert_equal "Sampled plugin character upload", event["message"]
    assert_equal "positive:10_to_99", event.dig("contexts", "upload_shape", "fields", "level", "range")
    refute_includes event.to_s, character
    refute_includes event.to_s, token
  ensure
    Sentry.close
  end

  it "defaults to off and validates the boot-time rate" do
    file = File.expand_path("../../lib/upload_sampling.rb", __dir__)
    command = [RbConfig.ruby, "-r", file, "-e", "print UploadSampling::RATE"]
    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => nil}, *command)
    assert status.success?
    assert_equal "0.0", output

    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "0.01"}, *command)
    assert status.success?
    assert_equal "0.01", output

    _, error, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "2"}, *command)
    refute status.success?
    assert_includes error, "UPLOAD_SAMPLE_RATE must be a number between 0 and 1"
  end

  it "samples at the configured endpoints of the rate range" do
    file = File.expand_path("../../lib/upload_sampling.rb", __dir__)
    command = [RbConfig.ruby, "-r", file, "-e", "print UploadSampling.sample({'level' => 50}).nil?"]

    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "0"}, *command)
    assert status.success?
    assert_equal "true", output

    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "1"}, *command)
    assert status.success?
    assert_equal "false", output
  end
end
