require_relative "../spec_helper"
require "open3"
require "rbconfig"
require "sentry-ruby"
require "sentry/transport/dummy_transport"
require_relative "../../lib/sentry_upload_filter"

describe UploadSampling do
  it "removes credentials from diagnostic logs without changing character data" do
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

  it "sends the exact plugin JSON as an attachment in the Sentry envelope" do
    Sentry.init do |config|
      config.dsn = "http://public@example.invalid/1"
      config.transport.transport_class = Sentry::DummyTransport
      config.background_worker_threads = 0
      config.enabled_environments = ["test"]
      config.before_send = SentryUploadFilter.method(:filter)
    end
    text = JSON.pretty_generate("name" => "Example Character", "key" => "example-key", "unknown" => "x" * 10_000)

    UploadSampling.capture(text)
    transport = Sentry.get_current_client.transport
    event = transport.events.fetch(0).to_json_compatible
    attachment = transport.envelopes.fetch(0).items.find { |item| item.headers[:type] == "attachment" }

    assert_equal "Sampled plugin character upload", event["message"]
    refute_nil attachment
    assert_equal "character-upload.json", attachment.headers[:filename]
    assert_equal "application/json", attachment.headers[:content_type]
    assert_equal text, attachment.payload
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
    command = [RbConfig.ruby, "-r", file, "-e", "print UploadSampling.sample('{}').nil?"]

    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "0"}, *command)
    assert status.success?
    assert_equal "true", output

    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "1"}, *command)
    assert status.success?
    assert_equal "false", output
  end

  it "copies the exact request body before it can be changed" do
    file = File.expand_path("../../lib/upload_sampling.rb", __dir__)
    script = <<~RUBY
      text = "{ \\"level\\": 50 }"
      sample = UploadSampling.sample(text)
      text.replace("changed")
      print sample
    RUBY
    output, _, status = Open3.capture3({"UPLOAD_SAMPLE_RATE" => "1"}, RbConfig.ruby, "-r", file, "-e", script)

    assert status.success?
    assert_equal '{ "level": 50 }', output
  end
end
