require_relative "../spec_helper"
require_relative "../../lib/data_poller"
require_relative "../../lib/sidekiq_job_metadata_middleware"
require "open3"
require "rbconfig"

describe "DataPoller", :unit do
  before do
    PlayerCount.destroy_all
    DataPollState.collection.delete_many
    DataPoller.ensure_indexes!
  end

  def next_slot
    @test_current_slot ||= DataPoller.current_slot
    @test_slot ||= @test_current_slot - 1
    @test_slot += 1
  end

  def with_test_slot(slot)
    original = DataPoller.method(:current_slot)
    DataPoller.define_singleton_method(:current_slot) { slot }
    yield
  ensure
    DataPoller.define_singleton_method(:current_slot, original)
  end

  def poll_for(server, transport, slot: next_slot)
    with_test_slot(slot) do
      DataPoller::Poll.new(server: server, url: "https://population.example.test/x", slot: slot, transport: transport).call
    end
  end

  def read_response(url, **options)
    DataPoller::Poll.new(server: "Test", url: url).read_response(**options)
  end

  def transport_for(data)
    lambda do |_uri|
      Struct.new(:code, :body).new("200", JSON.generate(data))
    end
  end

  it "accepts zero and ignores extra fields while storing measurement time and provenance" do
    timestamp = Time.now.to_i - 60
    result = poll_for("PollTest", transport_for({count: 0, updated_at: timestamp, server: "wrong", source: "plugin"}))
    assert_equal :accepted, result
    observation = PlayerCount.where(s: "PollTest").first
    assert_equal 0, observation.c
    assert_equal PlayerCount::SERVER_SOURCE, observation.source
    assert_equal "server", observation.effective_source
    assert_equal timestamp, observation.c_at.to_i
    refute_includes observation.serializable_hash({}).keys, "source"
  end

  it "accepts the standard population document with an RFC3339 measurement time" do
    timestamp = Time.now.utc - 60
    document = {
      schema: "https://treestats.net/schemas/asherons-call-server/v1/schema.json",
      version: 1,
      updated_at: timestamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
      name: "Dereth.AC",
      population: {
        count: 7,
        updated_at: "#{timestamp.strftime("%Y-%m-%dT%H:%M:%S")}.0526487Z"
      },
      emulator: {name: "ACE", version: "1.2.3"}
    }

    assert_equal :accepted, poll_for("Standard", transport_for(document))
    observation = PlayerCount.where(s: "Standard").first
    assert_equal 7, observation.c
    assert_equal timestamp.to_i, observation.c_at.to_i
    assert_equal PlayerCount::SERVER_SOURCE, observation.source
  end

  it "rejects malformed standard population documents" do
    now = Time.now.utc
    valid_time = (now - 60).strftime("%Y-%m-%dT%H:%M:%SZ")
    documents = [
      {population: nil},
      {population: []},
      {population: {count: 1}},
      {population: {updated_at: valid_time}},
      {population: {count: -1, updated_at: valid_time}},
      {population: {count: 1.0, updated_at: valid_time}},
      {population: {count: "1", updated_at: valid_time}},
      {population: {count: 1, updated_at: (now - 60).to_i}},
      {population: {count: 1, updated_at: (now - 60).strftime("%Y-%m-%dT%H:%M:%S")}},
      {population: {count: 1, updated_at: (now + 60).strftime("%Y-%m-%dT%H:%M:%SZ")}}
    ]

    documents.each do |document|
      assert_equal :failure, poll_for("InvalidStandard", transport_for(document)), document.inspect
    end
    assert_equal 0, PlayerCount.where(s: "InvalidStandard").count
  end

  it "derives HTTP root targets for listed servers and prefers explicit overrides" do
    first = DataPoller.server_list.first
    assert_equal "http://#{first[:host]}:#{first[:port]}/", DataPoller.discovered_targets[first[:name]]
    assert_equal DataPoller.server_list.size, DataPoller.discovered_targets.size
    assert DataPoller.discovered_targets.values.all? { |url| url.start_with?("http://") && url.end_with?("/") }
    assert_equal "https://hollowtide.org/population.json", DataPoller.targets["Hollowtide PK"]
  end

  it "accepts an old but advancing measurement and suppresses duplicate/conflicting/regressive timestamps" do
    start = Time.now.to_i - 7200
    assert_equal :accepted, poll_for("PollTest", transport_for(count: 2, updated_at: start))
    assert_equal :accepted, poll_for("PollTest", transport_for(count: 2, updated_at: start + 1))
    assert_equal :duplicate, poll_for("PollTest", transport_for(count: 2, updated_at: start + 1))
    assert_equal :failure, poll_for("PollTest", transport_for(count: 3, updated_at: start + 1))
    assert_equal :failure, poll_for("PollTest", transport_for(count: 4, updated_at: start))
    assert_equal 2, PlayerCount.where(s: "PollTest").count
  end

  it "rejects future/invalid data without inserting observations or moving cursor" do
    now = Time.now.to_i
    assert_equal :failure, poll_for("PollTest", transport_for(count: 1, updated_at: now + 60))
    assert_nil DataPollState.collection.find(server: "PollTest").first["last_accepted_updated_at"]
    [{count: -1, updated_at: now}, {count: 1.5, updated_at: now}, {count: 1, updated_at: now.to_s}, {updated_at: now}].each do |data|
      assert_equal :failure, poll_for("PollTest", transport_for(data))
    end
    assert_equal 0, PlayerCount.where(s: "PollTest").count
  end

  it "captures response receipt time after the request, allowing a timestamp made after request start" do
    request_started = Time.now.to_i
    timestamp = request_started + 1
    result = poll_for("PollTest", lambda { |_uri|
      sleep 1.1
      Struct.new(:code, :body).new("200", JSON.generate(count: 6, updated_at: timestamp))
    })
    assert_equal :accepted, result
    assert_equal 6, PlayerCount.where(s: "PollTest").first.c
  end

  it "rejects oversized and non-success responses without observations" do
    too_large = lambda { |_uri| Struct.new(:code, :body).new("200", "x" * (DataPoller::MAX_BODY_BYTES + 1)) }
    non_success = lambda { |_uri| Struct.new(:code, :body).new("302", "{}") }
    assert_equal :failure, poll_for("PollTest", too_large)
    assert_equal :failure, poll_for("PollTest", non_success)
    assert_equal 0, PlayerCount.where(s: "PollTest").count
  end

  it "allows simultaneous plugin observations and keeps internal fields out of public serialization" do
    time = Time.now.utc - 20
    PlayerCount.create!(server: "PollTest", count: 8)
    assert_equal :accepted, poll_for("PollTest", transport_for(count: 9, updated_at: time.to_i))
    assert_equal 2, PlayerCount.where(s: "PollTest").count
    serialized = PlayerCount.where(s: "PollTest", source: PlayerCount::SERVER_SOURCE).first.serializable_hash({})
    refute_includes serialized.keys, "source"
  end

  it "recovers a durable observation if writing the cursor fails after insert" do
    timestamp = Time.now.to_i - 30
    original = DataPoller::Poll.instance_method(:record_acceptance)
    failed_once = false
    DataPoller::Poll.define_method(:record_acceptance) do |updated_at, lease|
      unless failed_once
        failed_once = true
        raise "simulated cursor-write crash"
      end
      original.bind_call(self, updated_at, lease)
    end

    response = transport_for(count: 5, updated_at: timestamp)
    assert_equal :failure, poll_for("CrashCase", response)
    assert_equal 1, PlayerCount.where(s: "CrashCase").count
    assert_nil DataPollState.collection.find(server: "CrashCase").first["last_accepted_updated_at"]
    # A later value between the old cursor (nil) and the durable insert must be rejected.
    assert_equal :failure, poll_for("CrashCase", transport_for(count: 4, updated_at: timestamp - 1))
    assert_equal timestamp, DataPollState.collection.find(server: "CrashCase").first["last_accepted_updated_at"]
    assert_equal 1, PlayerCount.where(s: "CrashCase").count
    assert_equal :duplicate, poll_for("CrashCase", response)
    assert_equal 1, PlayerCount.where(s: "CrashCase").count
    assert_equal timestamp, DataPollState.collection.find(server: "CrashCase").first["last_accepted_updated_at"]
  ensure
    DataPoller::Poll.define_method(:record_acceptance, original)
    DataPoller::Poll.send(:private, :record_acceptance)
  end

  it "records one poll per slot, allows queue delay within slot, and rejects stale slots" do
    slot = DataPoller.current_slot
    timestamp = Time.now.to_i - 10
    transport = transport_for(count: 3, updated_at: timestamp)
    assert_equal :accepted, DataPoller::Poll.new(server: "SlotTest", url: "https://population.example.test/x", slot: slot, transport: transport).call
    assert_equal :already_polled, DataPoller::Poll.new(server: "SlotTest", url: "https://population.example.test/x", slot: slot, transport: transport).call
    assert_equal :obsolete, DataPoller::Poll.new(server: "SlotTest", url: "https://population.example.test/x", slot: slot - 1, transport: transport).call
    # A normal short queue delay in the same interval slot still runs.
    assert_equal :accepted, DataPoller::Poll.new(server: "DelayedQueue", url: "https://population.example.test/x", slot: slot, transport: transport).call
  end

  it "records ordinary and whole-job timeouts as failures without observations" do
    timeout_transport = ->(_uri) { raise Timeout::Error, "request timed out" }
    assert_equal :failure, poll_for("TimeoutState", timeout_transport)
    state = DataPollState.collection.find(server: "TimeoutState").first
    assert_equal "failure", state["last_outcome"]
    assert_equal 1, state["consecutive_failures"]
    assert_match(/Timeout::Error/, state["error_summary"])
    assert_equal 0, PlayerCount.where(s: "TimeoutState").count

    assert_raises(DataPoller::JobDeadlineExceeded) do
      poll_for("TimeoutState", ->(_uri) { raise DataPoller::JobDeadlineExceeded, "deadline" })
    end
    state = DataPollState.collection.find(server: "TimeoutState").first
    assert_equal "failure", state["last_outcome"]
    assert_equal 2, state["consecutive_failures"]
    assert_equal 0, PlayerCount.where(s: "TimeoutState").count
  end

  it "resets consecutive failures after a valid duplicate or accepted measurement" do
    timestamp = Time.now.to_i - 20
    assert_equal :failure, poll_for("FailureCount", transport_for(count: -1, updated_at: timestamp))
    assert_equal 1, DataPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
    assert_equal :accepted, poll_for("FailureCount", transport_for(count: 2, updated_at: timestamp))
    assert_equal 0, DataPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
    assert_equal :failure, poll_for("FailureCount", transport_for(count: 2, updated_at: timestamp - 1))
    assert_equal 1, DataPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
    # Same measurement at a later slot is a valid duplicate.
    assert_equal :duplicate, poll_for("FailureCount", transport_for(count: 2, updated_at: timestamp))
    assert_equal 0, DataPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
  end

  it "does not release or write under a replaced lease owner" do
    timestamp = Time.now.to_i - 10
    started = Queue.new
    continue = Queue.new
    transport = lambda do |_uri|
      started << true
      continue.pop
      Struct.new(:code, :body).new("200", JSON.generate(count: 2, updated_at: timestamp))
    end
    thread = Thread.new { poll_for("LeaseTest", transport) }
    Timeout.timeout(5) { started.pop }
    DataPollState.collection.update_one({server: "LeaseTest"}, {"$set" => {lease_until: Time.now.utc - 1, lease_id: "new-owner"}})
    continue << true
    assert_equal :overlap, thread.value
    current = DataPollState.collection.find(server: "LeaseTest").first
    assert_equal "new-owner", current["lease_id"]
    assert_equal 0, PlayerCount.where(s: "LeaseTest").count
  end

  it "uses observation time for latest ordering and daily maximum across sources" do
    today = Time.now.utc
    poll_time = today - 120
    plugin_time = today - 60
    PlayerCount.collection.insert_one({s: "Mixed", c: 40, c_at: poll_time, r: PlayerCount::SERVER_SOURCE})
    PlayerCount.collection.insert_one({s: "Mixed", c: 12, c_at: plugin_time, r: "p"})
    latest = JSON.parse(latest_player_counts).find { |item| item["server"] == "Mixed" }
    assert_equal 12, latest["count"]

    yesterday = Time.utc(today.year, today.month, today.day) - 86_400
    PlayerCount.collection.insert_one({s: "Mixed", c: 80, c_at: yesterday + 3600})
    PlayerCount.collection.insert_one({s: "Mixed", c: 100, c_at: yesterday + 7200, source: "server"})
    historical = JSON.parse(player_counts(["Mixed"], "All"))
    point = historical.find { |row| row["date"] == yesterday.strftime("%Y%m%d") }
    assert_equal 100, point["count"]
  end

  it "uses the partial unique index only for polled observations" do
    timestamp = Time.now.utc
    PlayerCount.collection.insert_one({s: "IndexTest", c: 1, c_at: timestamp, r: "p"})
    PlayerCount.collection.insert_one({s: "IndexTest", c: 2, c_at: timestamp, r: "p"})
    PlayerCount.collection.insert_one({s: "IndexTest", c: 3, c_at: timestamp, r: PlayerCount::SERVER_SOURCE})
    assert_raises(Mongo::Error::OperationFailure) do
      PlayerCount.collection.insert_one({s: "IndexTest", c: 4, c_at: timestamp, r: PlayerCount::SERVER_SOURCE})
    end
  end

  it "treats source-less legacy observations as plugin observations" do
    PlayerCount.collection.insert_one({s: "Legacy", c: 1, c_at: Time.now.utc})
    assert_equal "plugin", PlayerCount.where(s: "Legacy").first.effective_source
  end

  it "parses every supported interval unit, ignoring case and surrounding whitespace" do
    {
      "1m" => 60, "1min" => 60, "1mins" => 60, "1minute" => 60, "1minutes" => 60,
      "1h" => 3600, "1hr" => 3600, "1hrs" => 3600, "1hour" => 3600, "1hours" => 3600,
      "1d" => 86_400, "1day" => 86_400, "1days" => 86_400,
      " 15M " => 900, "\t2 HOURS\n" => 7200, "30 mins" => 1800
    }.each do |interval, seconds|
      assert_equal seconds, DataPoller.parse_interval(interval), interval.inspect
    end
  end

  it "rejects malformed or unsupported intervals" do
    [nil, "", "   ", "15", "m", "15s", "15 m extra", "-15m", "1.5h", "1h30m", "0m", "0d", "abc"].each do |interval|
      assert_raises(DataPoller::Error) { DataPoller.parse_interval(interval) }
    end
  end

  it "derives exact cron schedules only when the interval divides the schedule evenly" do
    {
      "1m" => "*/1 * * * *",
      "5m" => "*/5 * * * *",
      "15m" => "*/15 * * * *",
      "30m" => "*/30 * * * *",
      "60m" => "0 * * * *",
      "1h" => "0 * * * *",
      "2h" => "0 */2 * * *",
      "6h" => "0 */6 * * *",
      "12h" => "0 */12 * * *",
      "24h" => "0 0 * * *",
      "1d" => "0 0 * * *"
    }.each do |interval, cron|
      assert_equal cron, DataPoller.cron_expression(DataPoller.parse_interval(interval)), interval.inspect
    end

    ["45m", "90m", "5h", "7d", "48h"].each do |interval|
      assert_raises(DataPoller::Error) { DataPoller.cron_expression(DataPoller.parse_interval(interval)) }
    end
    assert_raises(DataPoller::Error) { DataPoller.cron_expression(0) }
  end

  it "disables retries, preserves dispatcher schedule slots, and skips obsolete work" do
    assert_equal false, PollDataJob.get_sidekiq_options["retry"]
    assert_equal false, DispatchDataPollsJob.get_sidekiq_options["retry"]
    slot = DataPoller.current_slot
    interval = DataPoller.interval_seconds
    middleware = SidekiqJobMetadataMiddleware.new
    delayed = middleware.call(nil, {"enqueued_at" => (slot - interval) * 1000}, "default") do
      DispatchDataPollsJob.new.perform
    end
    assert_equal :obsolete, delayed
    normal = middleware.call(nil, {"enqueued_at" => slot * 1000}, "default") do
      DispatchDataPollsJob.new.perform
    end
    assert_equal :dispatched, normal
    assert_equal slot, DataPoller.slot_from_enqueued_at(slot)
    assert_nil DataPoller.slot_from_enqueued_at((slot + interval) * 1000)
    job = PollDataJob.new
    assert_equal :obsolete, job.perform("NotRegistered", slot - interval)
    assert_nil job.perform("NotRegistered", slot)
  end

  it "runs a fresh standalone Sidekiq boot with PlayerCount loaded without Sinatra" do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", 'require "./lib/sidekiq_boot"; abort unless defined?(PlayerCount); puts "ready"')
    assert status.success?, stderr
    assert_equal "ready\n", stdout
  end

  it "validates the real HTTPS transport, TLS host and streamed body limit" do
    response = Object.new
    response.define_singleton_method(:code) { "200" }
    response.define_singleton_method(:read_body) { |&block| ["{\"count\":", "1,\"updated_at\":1}"].each(&block) }
    client = Object.new
    client.define_singleton_method(:start) { |&block| block.call(client) }
    client.define_singleton_method(:request) { |_request, &block| block.call(response) }
    options = {}
    %i[use_ssl verify_mode open_timeout read_timeout write_timeout max_retries].each do |name|
      client.define_singleton_method("#{name}=") { |value| options[name] = value }
    end
    result = read_response("https://public.example.test/population.json",
      http_factory: ->(host, port, proxy) {
        options[:host] = host
        options[:port] = port
        options[:proxy] = proxy
        client
      })
    assert_equal "{\"count\":1,\"updated_at\":1}", result.first
    assert_equal "public.example.test", options[:host]
    assert_equal true, options[:use_ssl]
    assert_equal OpenSSL::SSL::VERIFY_PEER, options[:verify_mode]
    assert_equal DataPoller::OPEN_TIMEOUT_SECONDS, options[:open_timeout]
    assert_equal DataPoller::READ_TIMEOUT_SECONDS, options[:read_timeout]
    assert_equal DataPoller::WRITE_TIMEOUT_SECONDS, options[:write_timeout]
    assert_equal 0, options[:max_retries]
    assert_nil options[:proxy]

    options.clear
    result = read_response("http://public.example.test/",
      http_factory: ->(host, port, proxy) {
        options[:host] = host
        options[:port] = port
        options[:proxy] = proxy
        client
      })
    assert_equal "{\"count\":1,\"updated_at\":1}", result.first
    assert_equal "public.example.test", options[:host]
    assert_equal false, options[:use_ssl]
    assert_nil options[:proxy]

    oversized = Object.new
    oversized.define_singleton_method(:code) { "200" }
    oversized.define_singleton_method(:read_body) { |&block| block.call("x" * (DataPoller::MAX_BODY_BYTES + 1)) }
    client.define_singleton_method(:request) { |_request, &block| block.call(oversized) }
    assert_raises(DataPoller::Error) do
      read_response("https://public.example.test/", http_factory: ->(*) { client })
    end

    client.define_singleton_method(:start) do |&block|
      sleep 0.05
      block.call(client)
    end
    assert_raises(Timeout::Error) do
      read_response("https://public.example.test/", http_factory: ->(*) { client }, total_timeout: 0.01)
    end
  end

  it "rejects non-HTTP response targets" do
    assert_raises(DataPoller::Error) { read_response("ftp://example.com/") }
  end
end
