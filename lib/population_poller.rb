# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "ipaddr"
require "socket"
require "uri"
require "yaml"
require "timeout"
require "securerandom"

module PopulationPoller
  MAX_BODY_BYTES = 16 * 1024
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 5
  WRITE_TIMEOUT = 5
  TOTAL_TIMEOUT = 12
  JOB_TIMEOUT = 90
  SLOT_SECONDS = 900
  LEASE_SECONDS = 120
  IPV4_BLOCKED = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4].map { |range| IPAddr.new(range) }.freeze
  IPV6_GLOBAL = IPAddr.new("2000::/3")
  IPV6_BLOCKED = %w[2001::/23 2001:db8::/32 2002::/16 3fff::/20].map { |range| IPAddr.new(range) }.freeze

  class Error < StandardError; end
  class JobDeadlineExceeded < Timeout::Error; end

  def self.feeds
    config = YAML.safe_load_file(File.expand_path("../config/population_feeds.yml", __dir__)) || {}
    config.fetch("feeds", {}).each_with_object({}) do |(server, url), result|
      raise Error, "invalid feed mapping for #{server}" unless server.is_a?(String) && url.is_a?(String)
      result[server] = url
    end
  end

  def self.ensure_indexes!
    PlayerCount.collection.indexes.create_one({s: 1, c_at: 1}, unique: true,
      partial_filter_expression: {source: "server"}, name: "unique_polled_measurement")
    PopulationPollState.collection.indexes.create_one({server: 1}, unique: true, name: "unique_poll_state_server")
  end

  def self.current_slot
    Time.now.to_i / SLOT_SECONDS
  end

  # Sidekiq 8 writes `enqueued_at` in epoch milliseconds; older persisted jobs
  # may contain seconds. Normalize both and reject future/malformed stamps.
  def self.slot_from_enqueued_at(value)
    stamp = Float(value)
    stamp /= 1000.0 if stamp > 100_000_000_000
    return nil unless stamp.positive?
    slot = stamp.to_i / SLOT_SECONDS
    return nil if slot > current_slot
    slot
  rescue ArgumentError, TypeError, FloatDomainError
    nil
  end

  def self.record_failure(server, lease_id, error)
    update = lambda do
      PopulationPollState.collection.update_one({server: server, lease_id: lease_id}, {"$set" => {last_checked_at: Time.now.utc, last_outcome: "failure", error_summary: "#{error.class}: #{error.message}".byteslice(0, 240)}, "$inc" => {consecutive_failures: 1}, "$unset" => {lease_until: "", lease_id: ""}})
    end
    Timeout.timeout(3) { update.call }
  rescue => state_error
    warn("Could not record population poll failure for #{server}: #{state_error.class}: #{state_error.message}")
  end

  def self.record_acceptance(server, timestamp, lease_id)
    result = PopulationPollState.collection.update_one({server: server, lease_id: lease_id}, {"$set" => {last_checked_at: Time.now.utc, last_outcome: "accepted", error_summary: nil, consecutive_failures: 0}, "$max" => {last_accepted_updated_at: timestamp}, "$unset" => {lease_until: "", lease_id: ""}})
    raise Error, "poll lease lost before cursor update" unless result.matched_count == 1
  end

  def self.dispatch(slot = current_slot)
    return :obsolete if slot < current_slot
    return :invalid_slot if slot > current_slot
    feeds.each_key { |server| PollPopulationJob.perform_async(server, slot) }
    :dispatched
  end

  def self.public_ip?(address)
    ip = IPAddr.new(address)
    return false if ip.ipv4_mapped? && !public_ip?(ip.native.to_s)
    if ip.ipv4?
      IPV4_BLOCKED.none? { |range| range.include?(ip) }
    else
      IPV6_GLOBAL.include?(ip) && IPV6_BLOCKED.none? { |range| range.include?(ip) }
    end
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.read_response(url, transport: nil, resolver: nil, http_factory: nil, total_timeout: TOTAL_TIMEOUT)
    uri = URI.parse(url)
    raise Error, "feed URL must be HTTPS without credentials or fragment" unless uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo && !uri.fragment
    injected_transport = transport || http_factory
    raise Error, "feed URL may not use a proxy" if !injected_transport && (ENV["https_proxy"] || ENV["HTTPS_PROXY"])
    # Resolver/HTTP injection is explicitly for tests; production uses the DNS-pinned client below.
    addresses = unless transport
      resolver ||= ->(host, port) { Addrinfo.getaddrinfo(host, port, nil, :STREAM).map(&:ip_address).uniq }
      resolved = Timeout.timeout(2) { resolver.call(uri.host, uri.port) }
      raise Error, "feed host resolves to a non-public address" if resolved.empty? || resolved.any? { |ip| !public_ip?(ip) }
      resolved
    end
    body = +""
    response = if transport
      stub = transport.call(uri)
      body = stub.body.to_s
      stub
    else
      http = http_factory ? http_factory.call(uri.host, uri.port, nil) : Net::HTTP.new(uri.host, uri.port, nil)
      http.ipaddr = addresses.first
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = WRITE_TIMEOUT if http.respond_to?(:write_timeout=)
      http.max_retries = 0 if http.respond_to?(:max_retries=)
      req = Net::HTTP::Get.new(uri.request_uri, {"Accept" => "application/json"})
      Timeout.timeout(total_timeout) do
        http.start do |connection|
          connection.request(req) do |res|
            res.read_body do |chunk|
              raise Error, "response body exceeds #{MAX_BODY_BYTES} bytes" if body.bytesize + chunk.bytesize > MAX_BODY_BYTES
              body << chunk
            end
            res
          end
        end
      end
    end
    response_time = Time.now.to_f
    raise Error, "HTTP status #{response.code}" unless response.code.to_i == 200
    raise Error, "response body exceeds #{MAX_BODY_BYTES} bytes" if body.bytesize > MAX_BODY_BYTES
    [body, response_time]
  end

  def self.poll(server, url, slot: current_slot, transport: nil)
    return :obsolete if slot < current_slot
    return :invalid_slot if slot > current_slot
    ensure_indexes!
    now = Time.now.utc
    lease_id = SecureRandom.uuid
    begin
      state = PopulationPollState.collection.find_one_and_update(
        {server: server, "$and" => [
          {"$or" => [{lease_until: {"$lte" => now}}, {lease_until: {"$exists" => false}}]},
          {"$or" => [{last_poll_slot: {"$lt" => slot}}, {last_poll_slot: {"$exists" => false}}]}
        ]},
        {"$setOnInsert" => {server: server, consecutive_failures: 0}, "$set" => {lease_until: now + LEASE_SECONDS, lease_id: lease_id, last_poll_slot: slot}},
        upsert: true, return_document: :after
      )
    rescue Mongo::Error::OperationFailure => error
      if error.code == 11000
        existing = PopulationPollState.collection.find(server: server).first
        return :already_polled if existing && existing["last_poll_slot"] == slot
        return :overlap
      end
      raise
    end
    return :overlap unless state && state["lease_until"] && state["lease_until"] > Time.now.utc + JOB_TIMEOUT + 2

    begin
      body, received_at = read_response(url, transport: transport)
      payload = JSON.parse(body)
      raise Error, "response must be an object" unless payload.is_a?(Hash)
      count = payload["count"]
      timestamp = payload["updated_at"]
      raise Error, "count must be a nonnegative integer" unless count.is_a?(Integer) && count >= 0
      raise Error, "updated_at must be an integer Unix timestamp" unless timestamp.is_a?(Integer) && timestamp >= 0
      raise Error, "updated_at is in the future" if timestamp > received_at.floor

      lease = PopulationPollState.collection.find(server: server, lease_id: lease_id).first
      return :overlap unless lease && lease["lease_until"] > Time.now.utc + 2

      # The observation write and state update are deliberately separate (Mongo
      # standalone has no transactions). Rebuild the high-water mark from the
      # durable uniquely-indexed observations before comparing this response.
      latest_observation = PlayerCount.collection.find(s: server, source: "server").sort(c_at: -1).limit(1).first
      durable_cursor = latest_observation && latest_observation["c_at"].to_i
      cursor = [state["last_accepted_updated_at"], durable_cursor].compact.max
      if cursor && cursor > state.fetch("last_accepted_updated_at", 0)
        PopulationPollState.collection.update_one({server: server, lease_id: lease_id}, {"$max" => {last_accepted_updated_at: cursor}})
      end
      if cursor && timestamp <= cursor
        existing = PlayerCount.collection.find(s: server, c_at: Time.at(timestamp).utc, source: "server").first
        if existing && existing["c"] == count
          # Recover the only crash window: observation insert succeeded, state update did not.
          PopulationPollState.collection.update_one({server: server, lease_id: lease_id}, {"$max" => {last_accepted_updated_at: timestamp}, "$set" => {last_checked_at: Time.now.utc, last_outcome: "duplicate", error_summary: nil, consecutive_failures: 0}, "$unset" => {lease_until: "", lease_id: ""}})
          return :duplicate
        end
        raise Error, existing ? "conflicting measurement timestamp" : "measurement timestamp did not advance"
      end

      lease = PopulationPollState.collection.find(server: server, lease_id: lease_id).first
      return :overlap unless lease && lease["lease_until"] > Time.now.utc + 2
      measured_at = Time.at(timestamp).utc
      begin
        PlayerCount.collection.insert_one({s: server, c: count, c_at: measured_at, source: "server", received_at: Time.at(received_at).utc})
      rescue Mongo::Error::OperationFailure => error
        raise unless error.code == 11000
        existing = PlayerCount.collection.find(s: server, c_at: measured_at, source: "server").first
        raise Error, "conflicting measurement timestamp" unless existing && existing["c"] == count
      end
      record_acceptance(server, timestamp, lease_id)
      :accepted
    rescue JobDeadlineExceeded => error
      warn("Population poll job exceeded its execution bound for #{server}")
      record_failure(server, lease_id, error)
      raise
    rescue => error
      warn("Population poll failed for #{server}: #{error.class}: #{error.message}")
      record_failure(server, lease_id, error)
      :failure
    end
  end
end

class PopulationPollState
  include Mongoid::Document
  store_in collection: "population_poll_states"
  field :server, type: String
  field :last_checked_at, type: Time
  field :last_outcome, type: String
  field :error_summary, type: String
  field :last_accepted_updated_at, type: Integer
  field :consecutive_failures, type: Integer, default: 0
end

class PollPopulationJob
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: :default

  def perform(server, slot = PopulationPoller.current_slot)
    return :obsolete if slot.to_i < PopulationPoller.current_slot
    url = PopulationPoller.feeds[server]
    return unless url
    Timeout.timeout(PopulationPoller::JOB_TIMEOUT, PopulationPoller::JobDeadlineExceeded) do
      PopulationPoller.poll(server, url, slot: slot.to_i)
    end
  rescue PopulationPoller::JobDeadlineExceeded
    :failure
  end
end

class DispatchPopulationPollsJob
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: :default

  def perform(scheduled_at = nil)
    enqueued_at = Thread.current[:sidekiq_enqueued_at]
    slot = if scheduled_at
      Integer(scheduled_at)
    elsif enqueued_at.nil?
      PopulationPoller.current_slot
    else
      PopulationPoller.slot_from_enqueued_at(enqueued_at)
    end
    return :invalid_slot unless slot
    PopulationPoller.dispatch(slot)
  rescue ArgumentError, TypeError
    :invalid_slot
  end
end
