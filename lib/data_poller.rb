# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"
require "yaml"
require "timeout"
require "securerandom"

module DataPoller
  MAX_BODY_BYTES = 16 * 1024
  OPEN_TIMEOUT_SECONDS = 5
  READ_TIMEOUT_SECONDS = 5
  WRITE_TIMEOUT_SECONDS = 5
  TOTAL_TIMEOUT_SECONDS = 12
  JOB_TIMEOUT_SECONDS = 90
  DEFAULT_INTERVAL = "15m"
  LEASE_SECONDS = 120
  INTERVAL_UNITS = {
    "m" => 60, "min" => 60, "mins" => 60, "minute" => 60, "minutes" => 60,
    "h" => 3600, "hr" => 3600, "hrs" => 3600, "hour" => 3600, "hours" => 3600,
    "d" => 86_400, "day" => 86_400, "days" => 86_400
  }.freeze
  INTERVAL_PATTERN = /\A\s*(\d+)\s*([a-z]+)\s*\z/i
  class Error < StandardError; end
  class JobDeadlineExceeded < Timeout::Error; end

  def self.config
    YAML.safe_load_file(File.expand_path("../config/polling_targets.yml", __dir__)) || {}
  end

  def self.targets
    config.fetch("targets", {}).each_with_object({}) do |(server, url), result|
      raise Error, "invalid target mapping for #{server}" unless server.is_a?(String) && url.is_a?(String)
      result[server] = url
    end
  end

  # Accepts friendly intervals such as "15m", "30 mins", "1hr", "6 hours", "1d".
  def self.parse_interval(value)
    match = INTERVAL_PATTERN.match(value.to_s)
    unit = match && INTERVAL_UNITS[match[2].downcase]
    raise Error, "invalid polling interval #{value.inspect}; use e.g. 15m or 1hr" unless unit
    seconds = match[1].to_i * unit
    raise Error, "polling interval must be at least 1 minute" if seconds < 60
    seconds
  end

  def self.interval_seconds
    parse_interval(config.fetch("interval", DEFAULT_INTERVAL))
  end

  # Sidekiq-cron only accepts cron expressions, so intervals must divide an hour
  # (minutes) or a day (hours) evenly. This keeps the schedule exact instead of
  # drifting at the hour/day boundary.
  def self.cron_expression(seconds = interval_seconds)
    minutes, remainder = seconds.divmod(60)
    raise Error, "polling interval must be a whole number of minutes" unless remainder.zero?
    raise Error, "polling interval must be at least 1 minute" if minutes.zero?

    if minutes < 60
      raise Error, "minute intervals must divide an hour evenly (e.g. 5m, 15m, 30m)" unless (60 % minutes).zero?
      return "*/#{minutes} * * * *"
    end

    hours, remainder = minutes.divmod(60)
    raise Error, "polling interval must be a whole number of hours" unless remainder.zero?
    return "0 0 * * *" if hours == 24
    raise Error, "hour intervals must divide a day evenly (e.g. 1hr, 6hr, 12hr)" unless hours < 24 && (24 % hours).zero?
    return "0 * * * *" if hours == 1

    "0 */#{hours} * * *"
  end

  def self.server_source_filter
    {"$or" => [{PlayerCount::SOURCE_FIELD => PlayerCount::SERVER_SOURCE}, {"source" => "server"}]}
  end

  def self.ensure_indexes!
    create_polled_measurement_index!
    DataPollState.collection.indexes.create_one({server: 1}, unique: true, name: "unique_poll_state_server")
  end

  def self.create_polled_measurement_index!
    PlayerCount.collection.indexes.create_one({s: 1, c_at: 1}, unique: true,
      partial_filter_expression: {PlayerCount::SOURCE_FIELD => PlayerCount::SERVER_SOURCE}, name: "unique_polled_measurement")
  rescue Mongo::Error::OperationFailure => error
    # Rebuild the index when upgrading from the legacy `source: "server"` filter.
    raise unless [85, 86].include?(error.code)
    PlayerCount.collection.indexes.drop_one("unique_polled_measurement")
    retry
  end

  # Slots are the epoch second at which the interval bucket starts, so changing
  # the configured interval does not renumber (and block) existing poll state.
  def self.slot_for(time)
    seconds = time.to_i
    seconds - (seconds % interval_seconds)
  end

  def self.current_slot
    slot_for(Time.now)
  end

  # Sidekiq 8 writes `enqueued_at` in epoch milliseconds; older persisted jobs
  # may contain seconds. Normalize both and reject future/malformed stamps.
  def self.slot_from_enqueued_at(value)
    stamp = Float(value)
    stamp /= 1000.0 if stamp > 100_000_000_000
    return nil unless stamp.positive?
    slot = slot_for(stamp)
    return nil if slot > current_slot
    slot
  rescue ArgumentError, TypeError, FloatDomainError
    nil
  end

  def self.dispatch(slot = current_slot)
    return :obsolete if slot < current_slot
    return :invalid_slot if slot > current_slot
    targets.each_key { |server| PollDataJob.perform_async(server, slot) }
    :dispatched
  end

  # Polls one server for one interval slot. The instance owns the lease,
  # request, and persistence state for that single poll.
  class Poll
    def initialize(server:, url:, slot: DataPoller.current_slot, transport: nil)
      @server = server
      @url = url
      @slot = slot
      @transport = transport
    end

    def call
      return :obsolete if @slot < DataPoller.current_slot
      return :invalid_slot if @slot > DataPoller.current_slot

      DataPoller.ensure_indexes!
      now = Time.now.utc
      lease_id = SecureRandom.uuid
      begin
        state = DataPollState.collection.find_one_and_update(
          {"server" => @server, "$and" => [
            {"$or" => [{lease_until: {"$lte" => now}}, {lease_until: {"$exists" => false}}]},
            {"$or" => [{last_poll_slot: {"$lt" => @slot}}, {last_poll_slot: {"$exists" => false}}]}
          ]},
          {"$setOnInsert" => {server: @server, consecutive_failures: 0}, "$set" => {lease_until: now + LEASE_SECONDS, lease_id: lease_id, last_poll_slot: @slot}},
          upsert: true, return_document: :after
        )
      rescue Mongo::Error::OperationFailure => error
        if error.code == 11000
          existing = DataPollState.collection.find(server: @server).first
          return :already_polled if existing && existing["last_poll_slot"] == @slot
          return :overlap
        end
        raise
      end
      return :overlap unless state && state["lease_until"] && state["lease_until"] > Time.now.utc + JOB_TIMEOUT_SECONDS + 2

      begin
        body, received_at = read_response
        payload = JSON.parse(body)
        raise Error, "response must be an object" unless payload.is_a?(Hash)
        count = payload["count"]
        timestamp = payload["updated_at"]
        raise Error, "count must be a nonnegative integer" unless count.is_a?(Integer) && count >= 0
        raise Error, "updated_at must be an integer Unix timestamp" unless timestamp.is_a?(Integer) && timestamp >= 0
        raise Error, "updated_at is in the future" if timestamp > received_at.floor

        lease = DataPollState.collection.find(server: @server, lease_id: lease_id).first
        return :overlap unless lease && lease["lease_until"] > Time.now.utc + 2

        # The observation write and state update are deliberately separate (Mongo
        # standalone has no transactions). Rebuild the high-water mark from the
        # durable uniquely-indexed observations before comparing this response.
        latest_observation = PlayerCount.collection.find({s: @server}.merge(DataPoller.server_source_filter)).sort(c_at: -1).limit(1).first
        durable_cursor = latest_observation && latest_observation["c_at"].to_i
        cursor = [state["last_accepted_updated_at"], durable_cursor].compact.max
        if cursor && cursor > state.fetch("last_accepted_updated_at", 0)
          DataPollState.collection.update_one({server: @server, lease_id: lease_id}, {"$max" => {last_accepted_updated_at: cursor}})
        end
        if cursor && timestamp <= cursor
          existing = PlayerCount.collection.find({s: @server, c_at: Time.at(timestamp).utc}.merge(DataPoller.server_source_filter)).first
          if existing && existing["c"] == count
            # Recover the only crash window: observation insert succeeded, state update did not.
            DataPollState.collection.update_one({server: @server, lease_id: lease_id}, {"$max" => {last_accepted_updated_at: timestamp}, "$set" => {last_checked_at: Time.now.utc, last_outcome: "duplicate", error_summary: nil, consecutive_failures: 0}, "$unset" => {lease_until: "", lease_id: ""}})
            return :duplicate
          end
          raise Error, existing ? "conflicting measurement timestamp" : "measurement timestamp did not advance"
        end

        lease = DataPollState.collection.find(server: @server, lease_id: lease_id).first
        return :overlap unless lease && lease["lease_until"] > Time.now.utc + 2
        measured_at = Time.at(timestamp).utc
        begin
          PlayerCount.create!(
            server: @server,
            count: count,
            c_at: measured_at,
            received_at: Time.at(received_at).utc,
            source: PlayerCount::SERVER_SOURCE
          )
        rescue Mongo::Error::OperationFailure => error
          raise unless error.code == 11000
          existing = PlayerCount.collection.find({s: @server, c_at: measured_at}.merge(DataPoller.server_source_filter)).first
          raise Error, "conflicting measurement timestamp" unless existing && existing["c"] == count
        end
        record_acceptance(timestamp, lease_id)
        :accepted
      rescue JobDeadlineExceeded => error
        warn("Data poll job exceeded its execution bound for #{@server}")
        record_failure(lease_id, error)
        raise
      rescue => error
        warn("Data poll failed for #{@server}: #{error.class}: #{error.message}")
        record_failure(lease_id, error)
        :failure
      end
    end

    def read_response(transport: @transport, http_factory: nil, total_timeout: TOTAL_TIMEOUT_SECONDS)
      uri = URI.parse(@url)
      raise Error, "target URL must be HTTPS without credentials or fragment" unless uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo && !uri.fragment
      injected_transport = transport || http_factory
      raise Error, "target URL may not use a proxy" if !injected_transport && (ENV["https_proxy"] || ENV["HTTPS_PROXY"])
      body = +""
      response = if transport
        stub = transport.call(uri)
        body = stub.body.to_s
        stub
      else
        http = http_factory ? http_factory.call(uri.host, uri.port, nil) : Net::HTTP.new(uri.host, uri.port, nil)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = OPEN_TIMEOUT_SECONDS
        http.read_timeout = READ_TIMEOUT_SECONDS
        http.write_timeout = WRITE_TIMEOUT_SECONDS if http.respond_to?(:write_timeout=)
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

    private

    def record_failure(lease_id, error)
      update = lambda do
        DataPollState.collection.update_one({server: @server, lease_id: lease_id}, {"$set" => {last_checked_at: Time.now.utc, last_outcome: "failure", error_summary: "#{error.class}: #{error.message}".byteslice(0, 240)}, "$inc" => {consecutive_failures: 1}, "$unset" => {lease_until: "", lease_id: ""}})
      end
      Timeout.timeout(3) { update.call }
    rescue => state_error
      warn("Could not record data poll failure for #{@server}: #{state_error.class}: #{state_error.message}")
    end

    def record_acceptance(timestamp, lease_id)
      result = DataPollState.collection.update_one({server: @server, lease_id: lease_id}, {"$set" => {last_checked_at: Time.now.utc, last_outcome: "accepted", error_summary: nil, consecutive_failures: 0}, "$max" => {last_accepted_updated_at: timestamp}, "$unset" => {lease_until: "", lease_id: ""}})
      raise Error, "poll lease lost before cursor update" unless result.matched_count == 1
    end
  end
end

class DataPollState
  include Mongoid::Document

  store_in collection: "data_poll_states"
  field :server, type: String
  field :last_checked_at, type: Time
  field :last_outcome, type: String
  field :error_summary, type: String
  field :last_accepted_updated_at, type: Integer
  field :consecutive_failures, type: Integer, default: 0
end

class PollDataJob
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: :default

  def perform(server, slot = DataPoller.current_slot)
    return :obsolete if slot.to_i < DataPoller.current_slot
    url = DataPoller.targets[server]
    return unless url
    Timeout.timeout(DataPoller::JOB_TIMEOUT_SECONDS, DataPoller::JobDeadlineExceeded) do
      DataPoller::Poll.new(server: server, url: url, slot: slot.to_i).call
    end
  rescue DataPoller::JobDeadlineExceeded
    :failure
  end
end

class DispatchDataPollsJob
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: :default

  def perform(scheduled_at = nil)
    enqueued_at = Thread.current[:sidekiq_enqueued_at]
    slot = if scheduled_at
      Integer(scheduled_at)
    elsif enqueued_at.nil?
      DataPoller.current_slot
    else
      DataPoller.slot_from_enqueued_at(enqueued_at)
    end
    return :invalid_slot unless slot
    DataPoller.dispatch(slot)
  rescue ArgumentError, TypeError
    :invalid_slot
  end
end
