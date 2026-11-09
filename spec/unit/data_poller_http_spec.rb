# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/data_poller"
require_relative "../support/mock_https_server"

describe "DataPoller HTTPS transport", :unit do
  def read_from(fixture, **options)
    DataPoller::Poll.new(server: "HTTPS test", url: fixture.url, slot: 0)
      .read_response(http_factory: fixture.http_factory, **options)
  end

  it "rejects an untrusted CA during a real TLS handshake" do
    MockHTTPSServer.open(->(_socket) { flunk "untrusted TLS must not reach HTTP" }) do |fixture|
      poll = DataPoller::Poll.new(server: "HTTPS test", url: fixture.url, slot: 0)
      assert_raises(OpenSSL::SSL::SSLError) do
        poll.read_response(http_factory: fixture.http_factory(trusted: false))
      end
      fixture.finish
      assert_empty fixture.requests
    end
  end

  it "rejects a trusted certificate for the wrong hostname" do
    MockHTTPSServer.open(->(_socket) { flunk "hostname mismatch must not reach HTTP" }) do |fixture|
      # The cert is trusted but has only DNS:localhost, not IP:127.0.0.1.
      poll = DataPoller::Poll.new(server: "HTTPS test", url: fixture.url(host: "127.0.0.1"), slot: 0)
      assert_raises(OpenSSL::SSL::SSLError) do
        poll.read_response(http_factory: fixture.http_factory)
      end
      fixture.finish
      assert_empty fixture.requests
    end
  end

  it "aborts an oversized chunked body before waiting for the final chunk" do
    handler = lambda do |socket|
      socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
      # Each HTTP chunk fits individually; only the accumulated body exceeds the cap.
      [DataPoller::MAX_BODY_BYTES / 2, DataPoller::MAX_BODY_BYTES / 2 + 1].each do |size|
        socket.write("#{size.to_s(16)}\r\n#{'x' * size}\r\n")
      end
      # Never finish the response. The size guard must close the socket now.
      socket.read(1)
    end
    MockHTTPSServer.open(handler) do |fixture|
      Timeout.timeout(3, MockHTTPSServer::DeadlineExceeded) do
        error = assert_raises(DataPoller::Error) { read_from(fixture) }
        assert_match(/response body exceeds/, error.message)
        fixture.finish
      end
    end
  end

  it "bounds a stalled response body and closes the connection" do
    handler = lambda do |socket|
      socket.write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n{")
      socket.read(1) # Wait for the timed-out client to disconnect, without sleeps.
    end
    MockHTTPSServer.open(handler) do |fixture|
      Timeout.timeout(3, MockHTTPSServer::DeadlineExceeded) do
        assert_raises(Timeout::Error) { read_from(fixture, total_timeout: 0.5) }
        fixture.finish
        assert_equal 1, fixture.requests.length
      end
    end
  end

  it "rejects an incomplete HTTP body even if the received prefix is valid JSON" do
    body = JSON.generate(population: {count: 5, updated_at: (Time.now.utc - 60).iso8601})
    handler = lambda do |socket|
      socket.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize + 10}\r\n\r\n#{body}")
      # Closing without the declared trailing bytes must not yield a measurement.
    end
    MockHTTPSServer.open(handler) do |fixture|
      assert_raises(EOFError) { read_from(fixture) }
      fixture.finish
    end
  end
end

# Override only client construction/deadline, leaving Poll#call and the real
# Net::HTTP request/streaming/TLS code under test. No production test switches.
class HTTPBackedTestPoll < DataPoller::Poll
  def initialize(fixture:, deadline: DataPoller::TOTAL_TIMEOUT_SECONDS, **options)
    super(url: fixture.url, **options)
    @fixture = fixture
    @deadline = deadline
  end

  def read_response
    super(http_factory: @fixture.http_factory, total_timeout: @deadline)
  end
end

describe "DataPoller HTTPS ingestion", :unit do
  before do
    PlayerCount.destroy_all
    DataPollState.collection.delete_many
    ServerInfo.collection.delete_many
  end

  def with_poll_slot(slot)
    original = DataPoller.method(:current_slot)
    DataPoller.define_singleton_method(:current_slot) { slot }
    yield
  ensure
    DataPoller.define_singleton_method(:current_slot, original)
  end

  def population_body(count, timestamp)
    JSON.generate(population: {count: count, updated_at: Time.at(timestamp).utc.iso8601})
  end

  def with_response(body)
    handler = ->(socket) { socket.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}") }
    MockHTTPSServer.open(handler) { |fixture| yield fixture }
  end

  it "does not poison the cursor on a real read timeout and recovers in the next slot" do
    slot = DataPoller.current_slot
    interval = DataPoller.interval_seconds
    timestamp = Time.now.to_i - 60
    with_response(population_body(4, timestamp)) do |fixture|
      with_poll_slot(slot) do
        assert_equal :accepted, HTTPBackedTestPoll.new(server: "Recovery", slot: slot, fixture: fixture).call
      end
    end

    stall = lambda do |socket|
      socket.write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n{")
      socket.read(1)
    end
    MockHTTPSServer.open(stall) do |fixture|
      with_poll_slot(slot + interval) do
        Timeout.timeout(3, MockHTTPSServer::DeadlineExceeded) do
          assert_equal :failure, HTTPBackedTestPoll.new(server: "Recovery", slot: slot + interval, fixture: fixture, deadline: 0.5).call
          fixture.finish
          assert_equal 1, fixture.requests.length
        end
      end
    end
    state = DataPollState.collection.find(server: "Recovery").first
    assert_equal timestamp, state["last_accepted_updated_at"]
    assert_equal 1, state["consecutive_failures"]
    assert_equal "failure", state["last_outcome"]
    refute state.key?("lease_id")
    assert_equal [4], PlayerCount.where(s: "Recovery").map(&:c)

    with_response(population_body(6, timestamp + 1)) do |fixture|
      with_poll_slot(slot + 2 * interval) do
        assert_equal :accepted, HTTPBackedTestPoll.new(server: "Recovery", slot: slot + 2 * interval, fixture: fixture).call
      end
    end
    state = DataPollState.collection.find(server: "Recovery").first
    assert_equal timestamp + 1, state["last_accepted_updated_at"]
    assert_equal 0, state["consecutive_failures"]
    assert_nil state["error_summary"]
    assert_equal 1, DataPollState.collection.count_documents(server: "Recovery")
    assert_equal [4, 6], PlayerCount.where(s: "Recovery").order_by(c_at: :asc).map(&:c)
  end

  it "uses completed-response time for a measurement made while the request is in flight" do
    # Construct certs before overriding Ruby's wall clock. No sleeps or reliance
    # on crossing a real second/slot boundary to test this acceptance boundary.
    MockHTTPSServer.identity
    started_at = Time.at(DataPoller.current_slot + 60).utc
    clock = started_at
    measured_at = started_at.to_i + 2
    body = population_body(7, measured_at)
    original_now = Time.method(:now)
    Time.define_singleton_method(:now) { clock }
    handler = lambda do |socket|
      clock = Time.at(measured_at).utc
      socket.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
    end
    MockHTTPSServer.open(handler) do |fixture|
      assert_equal :accepted, HTTPBackedTestPoll.new(server: "InFlight", fixture: fixture).call
    end
    assert_equal measured_at, PlayerCount.where(s: "InFlight").first.c_at.to_i
    assert_equal measured_at, DataPollState.collection.find(server: "InFlight").first["last_accepted_updated_at"]
  ensure
    Time.define_singleton_method(:now, original_now) if original_now
  end
end
