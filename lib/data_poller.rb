# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "openssl"
require "time"
require "uri"
require "timeout"
require "securerandom"

require_relative "data_poller_config"

module DataPoller
  MAX_BODY_BYTES = 16 * 1024
  OPEN_TIMEOUT_SECONDS = 5
  READ_TIMEOUT_SECONDS = 5
  WRITE_TIMEOUT_SECONDS = 5
  TOTAL_TIMEOUT_SECONDS = 12
  JOB_TIMEOUT_SECONDS = 90
  LEASE_SECONDS = 120
  # RFC3339 requires an explicit Z or ±HH:MM offset. DateTime.rfc3339 and
  # Time.iso8601 normalize out-of-range components (2026-02-30 -> 2026-03-02,
  # 24:00 -> next day), so reject those explicitly. The checks mirror
  # json_schemer's date-time format validation (MIT):
  # https://github.com/davishmcclurg/json_schemer/blob/v2.5.0/lib/json_schemer/format.rb
  RFC3339_OFFSET = /(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i
  RFC3339_HOUR_24 = /[Tt\s]24:/
  RFC3339_LEAP_SECOND = /[Tt\s]\d{2}:\d{2}:60/
  class JobDeadlineExceeded < Timeout::Error; end

  # Parsed standard server document. Timestamps are epoch seconds.
  Emulator = Struct.new(
    :name, :version, :server_version, :database_version, :dat_iterations,
    keyword_init: true
  )
  Document = Struct.new(
    :count, :measured_at, :document_updated_at, :name,
    :emulator, :schema_url, :document_version
  )

  # Parses the standard server document. All fields are optional. A count
  # without a measurement time (population.updated_at, falling back to the
  # document's updated_at) can be stored as a result but not as an observation.
  def self.parse_population(payload)
    raise Error, "response must be an object" unless payload.is_a?(Hash)

    # Temporary compatibility for targets such as Hollowtide that still serve
    # the legacy flat {"count", "updated_at"} shape. A standard document without
    # a population object does not have a top-level count.
    if !payload.key?("population") && payload.key?("count")
      count = payload["count"]
      raise Error, "count must be a nonnegative integer" unless count.is_a?(Integer) && count >= 0

      measured_at = payload["updated_at"]
      raise Error, "updated_at must be an integer Unix timestamp" unless measured_at.is_a?(Integer) && measured_at >= 0

      return Document.new(count: count, measured_at: measured_at)
    end

    document_updated_at = parse_rfc3339(payload["updated_at"], "updated_at") unless payload["updated_at"].nil?
    schema_url = optional_string(payload, "schema")
    document_version = optional_integer(payload, "version", minimum: 1)
    raise Error, "unsupported document version #{document_version}" if document_version && document_version != 1
    name = optional_string(payload, "name")
    emulator = parse_emulator(payload["emulator"])

    if payload.key?("population")
      population = payload["population"]
      raise Error, "population must be an object" unless population.is_a?(Hash)

      count = population["count"]
      valid_count = count.nil? || (count.is_a?(Integer) && count >= 0)
      raise Error, "count must be a nonnegative integer" unless valid_count
      measured_at = if population["updated_at"].nil?
        document_updated_at
      else
        parse_rfc3339(population["updated_at"], "population.updated_at")
      end
    else
      count = nil
      measured_at = nil
    end

    Document.new(
      count: count,
      measured_at: measured_at,
      document_updated_at: document_updated_at,
      name: name,
      emulator: emulator,
      schema_url: schema_url,
      document_version: document_version
    )
  end

  def self.optional_string(payload, key)
    value = payload[key]
    raise Error, "#{key} must be a string" unless value.nil? || value.is_a?(String)
    value
  end

  def self.optional_integer(payload, key, minimum: nil)
    value = payload[key]
    return value if value.nil?

    valid = value.is_a?(Integer) && (minimum.nil? || value >= minimum)
    message = minimum ? "#{key} must be an integer >= #{minimum}" : "#{key} must be an integer"
    raise Error, message unless valid
    value
  end

  def self.parse_emulator(emulator)
    return nil if emulator.nil?
    raise Error, "emulator must be an object" unless emulator.is_a?(Hash)

    name = emulator["name"]
    version = emulator["version"]
    server_version = emulator["server_version"]
    database_version = emulator["database_version"]
    dat_iterations = emulator["dat_iterations"]

    %w[name version server_version database_version].each do |key|
      value = emulator[key]
      raise Error, "emulator.#{key} must be a string" unless value.nil? || value.is_a?(String)
    end
    valid_dat_iterations = dat_iterations.nil? || (
      dat_iterations.is_a?(Hash) &&
      dat_iterations.values.all? { |value| value.is_a?(Integer) && value >= 0 }
    )
    raise Error, "emulator.dat_iterations must be an object of nonnegative integers" unless valid_dat_iterations

    Emulator.new(
      name: name,
      version: version,
      server_version: server_version,
      database_version: database_version,
      dat_iterations: dat_iterations
    )
  end

  def self.parse_rfc3339(value, field = "updated_at")
    raise Error, "#{field} must be an RFC3339 timestamp" unless valid_rfc3339?(value)

    Time.iso8601(value).to_i
  rescue ArgumentError, RangeError, TypeError
    raise Error, "#{field} must be an RFC3339 timestamp"
  end

  def self.valid_rfc3339?(value)
    return false unless value.is_a?(String)
    return false if RFC3339_HOUR_24.match?(value)

    datetime = DateTime.rfc3339(value)
    return false if RFC3339_LEAP_SECOND.match?(value) && datetime.new_offset.strftime("%H:%M") != "23:59"

    RFC3339_OFFSET.match?(value)
  rescue ArgumentError
    false
  end
  private_class_method :valid_rfc3339?

  def self.server_source_filter
    {"$or" => [{PlayerCount::SOURCE_FIELD => PlayerCount::SERVER_SOURCE}, {"source" => "server"}]}
  end

  def self.ensure_indexes!
    create_polled_measurement_index!
    DataPollState.collection.indexes.create_one({server: 1}, unique: true, name: "unique_poll_state_server")
    ServerInfo.collection.indexes.create_one({server: 1}, unique: true, name: "unique_server_info_server")
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
    def initialize(server:, url:, fallback_url: nil, slot: DataPoller.current_slot, transport: nil)
      @server = server
      @url = url
      @fallback_url = fallback_url
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
        body, received_at = read_response_with_fallback
        result = DataPoller.parse_population(JSON.parse(body))
        if result.count.nil? || result.measured_at.nil?
          return record_unmeasured(result, received_at, lease_id)
        end
        count = result.count
        timestamp = result.measured_at
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
            record_server_info(result, "duplicate")
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
            source: PlayerCount::SERVER_SOURCE
          )
        rescue Mongo::Error::OperationFailure => error
          raise unless error.code == 11000
          existing = PlayerCount.collection.find({s: @server, c_at: measured_at}.merge(DataPoller.server_source_filter)).first
          raise Error, "conflicting measurement timestamp" unless existing && existing["c"] == count
        end
        record_acceptance(timestamp, lease_id)
        record_server_info(result, "accepted")
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

    def read_response(url: @url, transport: @transport, http_factory: nil, total_timeout: TOTAL_TIMEOUT_SECONDS)
      uri = DataPoller.parse_http_url(url)
      body = +""
      response = if transport
        stub = transport.call(uri)
        body = stub.body.to_s
        stub
      else
        # Pass nil as the proxy address so Net::HTTP connects directly even when
        # http_proxy/HTTP_PROXY/https_proxy/HTTPS_PROXY are set.
        http = http_factory ? http_factory.call(uri.host, uri.port, nil) : Net::HTTP.new(uri.host, uri.port, nil)
        http.use_ssl = uri.is_a?(URI::HTTPS)
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

    def read_response_with_fallback
      return read_response unless @fallback_url

      begin
        read_response
      rescue JobDeadlineExceeded
        raise
      rescue => primary_error
        begin
          read_response(url: @fallback_url)
        rescue => fallback_error
          raise Error, "both endpoints failed: #{@url} (#{primary_error.class}: #{primary_error.message}); #{@fallback_url} (#{fallback_error.class}: #{fallback_error.message})"
        end
      end
    end

    def record_unmeasured(result, received_at, lease_id)
      lease = DataPollState.collection.find(server: @server, lease_id: lease_id).first
      return :overlap unless lease && lease["lease_until"] > Time.now.utc + 2

      outcome = result.count.nil? ? "empty" : "no_timestamp"
      updated = DataPollState.collection.update_one(
        {server: @server, lease_id: lease_id},
        {"$set" => {last_checked_at: Time.now.utc, last_outcome: outcome, error_summary: nil, consecutive_failures: 0}, "$unset" => {lease_until: "", lease_id: ""}}
      )
      return :overlap unless updated.matched_count == 1

      record_server_info(result, outcome)
      outcome.to_sym
    end

    def record_server_info(result, outcome)
      now = Time.now.utc
      ServerInfo.collection.update_one(
        {server: @server},
        {
          "$set" => {
            server: @server,
            updated_at: now,
            outcome: outcome,
            count: result.count,
            population_updated_at: result.measured_at && Time.at(result.measured_at).utc,
            document_updated_at: result.document_updated_at && Time.at(result.document_updated_at).utc,
            name: result.name,
            emulator_name: result.emulator&.name,
            emulator_version: result.emulator&.version,
            emulator_server_version: result.emulator&.server_version,
            emulator_database_version: result.emulator&.database_version,
            emulator_dat_iterations: result.emulator&.dat_iterations,
            schema_url: result.schema_url,
            document_version: result.document_version
          },
          "$setOnInsert" => {created_at: now}
        },
        upsert: true
      )
    rescue => error
      warn("Could not record server info for #{@server}: #{error.class}: #{error.message}")
    end

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

class PollDataJob
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: :default

  def perform(server, slot = DataPoller.current_slot)
    return :obsolete if slot.to_i < DataPoller.current_slot
    target = DataPoller.targets[server]
    return unless target
    Timeout.timeout(DataPoller::JOB_TIMEOUT_SECONDS, DataPoller::JobDeadlineExceeded) do
      DataPoller::Poll.new(server: server, url: target.url, fallback_url: target.fallback_url, slot: slot.to_i).call
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
  rescue DataPoller::Error => error
    warn("Data poll dispatch failed: #{error.class}: #{error.message}")
    :invalid_config
  rescue ArgumentError, TypeError
    :invalid_slot
  end
end
