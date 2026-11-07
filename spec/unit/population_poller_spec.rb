require_relative '../spec_helper'
require_relative '../../lib/population_poller'
require_relative '../../lib/sidekiq_job_metadata_middleware'
require 'open3'
require 'rbconfig'

describe "PopulationPoller", :unit do
  before do
    PlayerCount.destroy_all
    PopulationPollState.collection.delete_many
    PopulationPoller.ensure_indexes!
  end

  def next_slot
    @test_current_slot ||= PopulationPoller.current_slot
    @test_slot ||= @test_current_slot - 1
    @test_slot += 1
  end

  def with_test_slot(slot)
    original = PopulationPoller.method(:current_slot)
    PopulationPoller.define_singleton_method(:current_slot) { slot }
    yield
  ensure
    PopulationPoller.define_singleton_method(:current_slot, original)
  end

  def poll_for(server, transport, slot: next_slot)
    with_test_slot(slot) do
      PopulationPoller.poll(server, "https://population.example.test/x", slot: slot, transport: transport)
    end
  end

  def transport_for(data)
    lambda do |_uri|
      Struct.new(:code, :body).new("200", JSON.generate(data))
    end
  end

  it "accepts zero, extra fields ignored; stores measurement time, provenance and receipt separately" do
    timestamp = Time.now.to_i - 60
    result = poll_for("PollTest", transport_for({count: 0, updated_at: timestamp, server: "wrong", source: "plugin"}))
    assert_equal :accepted, result
    observation = PlayerCount.where(s: "PollTest").first
    assert_equal 0, observation.c
    assert_equal "server", observation.source
    assert_equal timestamp, observation.c_at.to_i
    refute_nil observation.received_at
    refute_includes observation.serializable_hash({}).keys, "source"
    refute_includes observation.serializable_hash({}).keys, "received_at"
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
    assert_nil PopulationPollState.collection.find(server: "PollTest").first["last_accepted_updated_at"]
    [ {count: -1, updated_at: now}, {count: 1.5, updated_at: now}, {count: 1, updated_at: "#{now}"}, {updated_at: now} ].each do |data|
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
    too_large = lambda { |_uri| Struct.new(:code, :body).new("200", "x" * (PopulationPoller::MAX_BODY_BYTES + 1)) }
    non_success = lambda { |_uri| Struct.new(:code, :body).new("302", "{}") }
    assert_equal :failure, poll_for("PollTest", too_large)
    assert_equal :failure, poll_for("PollTest", non_success)
    assert_equal 0, PlayerCount.where(s: "PollTest").count
  end

  it "allows simultaneous plugin observations and keeps internal fields out of public serialization" do
    time = Time.now.utc - 20
    PlayerCount.create!(server: "PollTest", count: 8, source: "plugin")
    assert_equal :accepted, poll_for("PollTest", transport_for(count: 9, updated_at: time.to_i))
    assert_equal 2, PlayerCount.where(s: "PollTest").count
    serialized = PlayerCount.where(s: "PollTest", source: "server").first.serializable_hash({})
    refute_includes serialized.keys, "source"
    refute_includes serialized.keys, "received_at"
  end

  it "recovers a durable observation if writing the cursor fails after insert" do
    timestamp = Time.now.to_i - 30
    original = PopulationPoller.method(:record_acceptance)
    failed_once = false
    PopulationPoller.define_singleton_method(:record_acceptance) do |server, updated_at, lease|
      unless failed_once
        failed_once = true
        raise "simulated cursor-write crash"
      end
      original.call(server, updated_at, lease)
    end

    response = transport_for(count: 5, updated_at: timestamp)
    assert_equal :failure, poll_for("CrashCase", response)
    assert_equal 1, PlayerCount.where(s: "CrashCase").count
    assert_nil PopulationPollState.collection.find(server: "CrashCase").first["last_accepted_updated_at"]
    # A later value between the old cursor (nil) and the durable insert must be rejected.
    assert_equal :failure, poll_for("CrashCase", transport_for(count: 4, updated_at: timestamp - 1))
    assert_equal timestamp, PopulationPollState.collection.find(server: "CrashCase").first["last_accepted_updated_at"]
    assert_equal 1, PlayerCount.where(s: "CrashCase").count
    assert_equal :duplicate, poll_for("CrashCase", response)
    assert_equal 1, PlayerCount.where(s: "CrashCase").count
    assert_equal timestamp, PopulationPollState.collection.find(server: "CrashCase").first["last_accepted_updated_at"]
  ensure
    PopulationPoller.define_singleton_method(:record_acceptance, original)
  end

  it "records one poll per slot, allows queue delay within slot, and rejects stale slots" do
    slot = PopulationPoller.current_slot
    timestamp = Time.now.to_i - 10
    transport = transport_for(count: 3, updated_at: timestamp)
    assert_equal :accepted, PopulationPoller.poll("SlotTest", "https://population.example.test/x", slot: slot, transport: transport)
    assert_equal :already_polled, PopulationPoller.poll("SlotTest", "https://population.example.test/x", slot: slot, transport: transport)
    assert_equal :obsolete, PopulationPoller.poll("SlotTest", "https://population.example.test/x", slot: slot - 1, transport: transport)
    # A normal short queue delay in the same quarter-hour slot still runs.
    assert_equal :accepted, PopulationPoller.poll("DelayedQueue", "https://population.example.test/x", slot: slot, transport: transport)
  end

  it "records ordinary and whole-job timeouts as failures without observations" do
    timeout_transport = ->(_uri) { raise Timeout::Error, "request timed out" }
    assert_equal :failure, poll_for("TimeoutState", timeout_transport)
    state = PopulationPollState.collection.find(server: "TimeoutState").first
    assert_equal "failure", state["last_outcome"]
    assert_equal 1, state["consecutive_failures"]
    assert_match(/Timeout::Error/, state["error_summary"])
    assert_equal 0, PlayerCount.where(s: "TimeoutState").count

    assert_raises(PopulationPoller::JobDeadlineExceeded) do
      poll_for("TimeoutState", ->(_uri) { raise PopulationPoller::JobDeadlineExceeded, "deadline" })
    end
    state = PopulationPollState.collection.find(server: "TimeoutState").first
    assert_equal "failure", state["last_outcome"]
    assert_equal 2, state["consecutive_failures"]
    assert_equal 0, PlayerCount.where(s: "TimeoutState").count
  end

  it "resets consecutive failures after a valid duplicate or accepted measurement" do
    timestamp = Time.now.to_i - 20
    assert_equal :failure, poll_for("FailureCount", transport_for(count: -1, updated_at: timestamp))
    assert_equal 1, PopulationPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
    assert_equal :accepted, poll_for("FailureCount", transport_for(count: 2, updated_at: timestamp))
    assert_equal 0, PopulationPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
    assert_equal :failure, poll_for("FailureCount", transport_for(count: 2, updated_at: timestamp - 1))
    assert_equal 1, PopulationPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
    # Same measurement at a later slot is a valid duplicate.
    assert_equal :duplicate, poll_for("FailureCount", transport_for(count: 2, updated_at: timestamp))
    assert_equal 0, PopulationPollState.collection.find(server: "FailureCount").first["consecutive_failures"]
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
    state = PopulationPollState.collection.find(server: "LeaseTest").first
    PopulationPollState.collection.update_one({server: "LeaseTest"}, {"$set" => {lease_until: Time.now.utc - 1, lease_id: "new-owner"}})
    continue << true
    assert_equal :overlap, thread.value
    current = PopulationPollState.collection.find(server: "LeaseTest").first
    assert_equal "new-owner", current["lease_id"]
    assert_equal 0, PlayerCount.where(s: "LeaseTest").count
  end

  it "uses observation time for latest ordering and daily maximum across sources" do
    today = Time.now.utc
    poll_time = today - 120
    plugin_time = today - 60
    PlayerCount.collection.insert_one({s: "Mixed", c: 40, c_at: poll_time, source: "server", received_at: today})
    PlayerCount.collection.insert_one({s: "Mixed", c: 12, c_at: plugin_time, source: "plugin"})
    latest = JSON.parse(latest_player_counts).find { |item| item["server"] == "Mixed" }
    assert_equal 12, latest["count"]

    yesterday = Time.utc(today.year, today.month, today.day) - 86_400
    PlayerCount.collection.insert_one({s: "Mixed", c: 80, c_at: yesterday + 3600, source: "plugin"})
    PlayerCount.collection.insert_one({s: "Mixed", c: 100, c_at: yesterday + 7200, source: "server", received_at: today})
    historical = JSON.parse(player_counts(["Mixed"], "All"))
    point = historical.find { |row| row["date"] == (yesterday.strftime("%Y%m%d")) }
    assert_equal 100, point["count"]
  end

  it "uses the partial unique index only for polled observations" do
    timestamp = Time.now.utc
    PlayerCount.collection.insert_one({s: "IndexTest", c: 1, c_at: timestamp, source: "plugin"})
    PlayerCount.collection.insert_one({s: "IndexTest", c: 2, c_at: timestamp, source: "plugin"})
    PlayerCount.collection.insert_one({s: "IndexTest", c: 3, c_at: timestamp, source: "server"})
    assert_raises(Mongo::Error::OperationFailure) do
      PlayerCount.collection.insert_one({s: "IndexTest", c: 4, c_at: timestamp, source: "server"})
    end
  end

  it "treats source-less legacy observations as plugin observations" do
    PlayerCount.collection.insert_one({s: "Legacy", c: 1, c_at: Time.now.utc})
    assert_equal "plugin", PlayerCount.where(s: "Legacy").first.effective_source
  end

  it "disables retries, preserves dispatcher schedule slots, and skips obsolete work" do
    assert_equal false, PollPopulationJob.get_sidekiq_options["retry"]
    assert_equal false, DispatchPopulationPollsJob.get_sidekiq_options["retry"]
    slot = PopulationPoller.current_slot
    middleware = SidekiqJobMetadataMiddleware.new
    delayed = middleware.call(nil, {"enqueued_at" => ((slot - 1) * PopulationPoller::SLOT_SECONDS * 1000)}, "default") do
      DispatchPopulationPollsJob.new.perform
    end
    assert_equal :obsolete, delayed
    normal = middleware.call(nil, {"enqueued_at" => (slot * PopulationPoller::SLOT_SECONDS * 1000)}, "default") do
      DispatchPopulationPollsJob.new.perform
    end
    assert_equal :dispatched, normal
    assert_equal slot, PopulationPoller.slot_from_enqueued_at(slot * PopulationPoller::SLOT_SECONDS)
    assert_nil PopulationPoller.slot_from_enqueued_at((slot + 1) * PopulationPoller::SLOT_SECONDS * 1000)
    job = PollPopulationJob.new
    assert_equal :obsolete, job.perform("NotRegistered", slot - 1)
    assert_nil job.perform("NotRegistered", slot)
  end

  it "runs a fresh standalone Sidekiq boot with PlayerCount loaded without Sinatra" do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", 'require "./lib/sidekiq_boot"; abort unless defined?(PlayerCount); puts "ready"')
    assert status.success?, stderr
    assert_equal "ready\n", stdout
  end

  it "validates and pins the real HTTPS transport, TLS host and streamed body limit" do
    response = Object.new
    response.define_singleton_method(:code) { "200" }
    response.define_singleton_method(:read_body) { |&block| ["{\"count\":", "1,\"updated_at\":1}"].each(&block) }
    client = Object.new
    client.define_singleton_method(:start) { |&block| block.call(client) }
    client.define_singleton_method(:request) { |_request, &block| block.call(response) }
    options = {}
    %i[ipaddr use_ssl verify_mode open_timeout read_timeout write_timeout max_retries].each do |name|
      client.define_singleton_method("#{name}=") { |value| options[name] = value }
    end
    result = PopulationPoller.read_response("https://public.example.test/population.json",
      resolver: ->(_host, _port) { ["8.8.8.8"] }, http_factory: ->(host, port, proxy) { options[:host] = host; options[:port] = port; options[:proxy] = proxy; client })
    assert_equal "{\"count\":1,\"updated_at\":1}", result.first
    assert_equal "public.example.test", options[:host]
    assert_equal "8.8.8.8", options[:ipaddr]
    assert_equal true, options[:use_ssl]
    assert_equal OpenSSL::SSL::VERIFY_PEER, options[:verify_mode]
    assert_equal PopulationPoller::OPEN_TIMEOUT, options[:open_timeout]
    assert_equal PopulationPoller::READ_TIMEOUT, options[:read_timeout]
    assert_equal PopulationPoller::WRITE_TIMEOUT, options[:write_timeout]
    assert_equal 0, options[:max_retries]
    assert_nil options[:proxy]

    assert_raises(PopulationPoller::Error) do
      PopulationPoller.read_response("https://private.example.test/", resolver: ->(*) { ["10.0.0.1"] }, http_factory: ->(*) { flunk "must not connect" })
    end

    oversized = Object.new
    oversized.define_singleton_method(:code) { "200" }
    oversized.define_singleton_method(:read_body) { |&block| block.call("x" * (PopulationPoller::MAX_BODY_BYTES + 1)) }
    client.define_singleton_method(:request) { |_request, &block| block.call(oversized) }
    assert_raises(PopulationPoller::Error) do
      PopulationPoller.read_response("https://public.example.test/", resolver: ->(*) { ["8.8.8.8"] }, http_factory: ->(*) { client })
    end

    client.define_singleton_method(:start) { |&block| sleep 0.05; block.call(client) }
    assert_raises(Timeout::Error) do
      PopulationPoller.read_response("https://public.example.test/", resolver: ->(*) { ["8.8.8.8"] }, http_factory: ->(*) { client }, total_timeout: 0.01)
    end
  end

  it "blocks special/private IP destinations and rejects non-HTTPS responses" do
    refute PopulationPoller.public_ip?("127.0.0.1")
    refute PopulationPoller.public_ip?("::ffff:192.168.0.1")
    refute PopulationPoller.public_ip?("2001:20::1")
    refute PopulationPoller.public_ip?("2002:0808:0808::1")
    refute PopulationPoller.public_ip?("3fff::1")
    assert PopulationPoller.public_ip?("8.8.8.8")
    assert PopulationPoller.public_ip?("2001:4860:4860::8888")
    assert_raises(PopulationPoller::Error) { PopulationPoller.read_response("http://example.com/") }
  end
end
