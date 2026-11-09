require_relative "../spec_helper"
require "open3"
require "rbconfig"
require "sentry-ruby"
require "sentry/transport/dummy_transport"
require_relative "../../lib/sentry_upload_filter"

describe UploadSampling do
  it "preserves real plugin data and unknown fields while removing credentials" do
    payload = JSON.parse(File.read(File.expand_path("../../util/plugin/plugin_message.txt", __dir__)))
    payload["extra_game_field"] = {"value" => 123, "token" => "credential"}
    sample = UploadSampling.without_credentials(payload)

    assert_equal payload["name"], sample["name"]
    assert_equal payload["birth"], sample["birth"]
    assert_equal payload["skills"], sample["skills"]
    assert_equal({"value" => 123}, sample["extra_game_field"])
    refute sample.key?("key")
    assert payload.key?("key")
  end

  it "sends the character payload through Sentry without credentials" do
    Sentry.init do |config|
      config.dsn = "http://public@example.invalid/1"
      config.transport.transport_class = Sentry::DummyTransport
      config.background_worker_threads = 0
      config.enabled_environments = ["test"]
      config.before_send = SentryUploadFilter.method(:filter)
    end
    payload = {"name" => "Example Character", "skills" => {"alchemy" => {"base" => 500}}, "key" => "credential"}

    UploadSampling.capture(UploadSampling.without_credentials(payload))
    event = Sentry.get_current_client.transport.events.fetch(0).to_json_compatible

    assert_equal "Sampled plugin character upload", event["message"]
    assert_equal "Example Character", event.dig("contexts", "character_upload", "name")
    assert_equal 500, event.dig("contexts", "character_upload", "skills", "alchemy", "base")
    refute event.dig("contexts", "character_upload").key?("key")
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

  it "captures original values before later changes to the payload" do
    file = File.expand_path("../../lib/upload_sampling.rb", __dir__)
    script = <<~RUBY
      require "json"
      payload = {"name" => "Example", "skills" => {"alchemy" => {"base" => 500}}, "key" => "credential"}
      sample = UploadSampling.sample(payload)
      payload["skills"]["alchemy"]["base"] = 1
      print JSON.generate(sample)
    RUBY
    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "1"}, RbConfig.ruby, "-r", file, "-e", script)

    assert status.success?
    assert_equal({"name" => "Example", "skills" => {"alchemy" => {"base" => 500}}}, JSON.parse(output))
  end
end
