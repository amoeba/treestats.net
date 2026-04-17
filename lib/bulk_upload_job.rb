# frozen_string_literal: true

require "sidekiq"
require "json"

class BulkUploadJob
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(file_path, content_type, log_id = nil)
    log = log_id ? (begin; BulkUploadLog.find(log_id); rescue Mongoid::Errors::DocumentNotFound; nil; end) : nil
    started_at = Time.now.utc
    log&.set(started_at: started_at, status: "processing")

    # NOTE: file_path is a local /tmp file; web and worker must share the same filesystem.
    body = File.read(file_path)
    records = parse_records(body, content_type)

    logger.info "BulkUploadJob: starting, #{records.length} records"

    processed = 0
    skipped   = 0
    errors    = 0

    records.each do |record|
      result = process_record(record)
      case result
      when :skipped then skipped += 1
      when :error   then errors  += 1
      else               processed += 1
      end
    end

    completed_at = Time.now.utc
    logger.info "BulkUploadJob: done — processed=#{processed} skipped=#{skipped} errors=#{errors}"
    log&.set(
      completed_at:    completed_at,
      duration_ms:     ((completed_at - started_at) * 1000).round,
      processed_count: processed,
      skipped_count:   skipped,
      error_count:     errors,
      status:          "completed"
    )
  rescue => e
    log&.set(status: "failed")
    raise
  ensure
    File.delete(file_path) if file_path && File.exist?(file_path)
    BulkUploadHelper.decrement_inflight!
  end

  private

  def parse_records(body, content_type)
    if content_type.include?("application/json")
      parsed = JSON.parse(body)
      parsed.is_a?(Array) ? parsed : [parsed]
    else
      # NDJSON: one JSON object per line
      body.each_line.map(&:strip).reject(&:empty?).filter_map do |line|
        JSON.parse(line)
      rescue JSON::ParserError => e
        logger.error "BulkUploadJob: skipping malformed NDJSON line: #{e}"
        nil
      end
    end
  end

  def process_record(record)
    if AppHelper.retail_servers.include?(record["server"])
      logger.warn "BulkUploadJob: skipping retail server character #{record["name"].inspect} on #{record["server"].inspect}"
      return :skipped
    end

    record.delete("key")
    record.delete("account_name")
    record.delete("ip_address")

    name = record["name"]
    server = record["server"]
    return :skipped if name.nil? || server.nil?

    allegiance_name = record["allegiance_name"]

    if record.key?("server_population")
      server_pop = record.delete("server_population")
      PlayerCount.where(server: server).find_one_and_update({ "$set" => { count: server_pop } }, upsert: true)
    end

    if record.key?("birth")
      record["birth"] = CharacterHelper.parse_birth(record["birth"])
    end

    if record.dig("patron", "name") == "??"
      logger.warn "BulkUploadJob: skipping #{name.inspect} on #{server.inspect} due to malformed patron name"
      return :skipped
    end

    character = Character.unscoped.find_or_create_by(name: name, server: server)
    character.assign_attributes(record)
    character[:archived] = false if character[:archived]
    character.location = nil unless record["location"]
    character.monarch  = nil unless record["monarch"]
    character.patron   = nil unless record["patron"]
    character.vassals  = nil unless record["vassals"]

    character.save!

    Allegiance.find_or_create_by(server: server, name: allegiance_name) if allegiance_name

    :processed
  rescue => e
    logger.error "BulkUploadJob: error processing #{record["name"].inspect}: #{e}"
    :error
  end
end
