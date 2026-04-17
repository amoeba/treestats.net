# frozen_string_literal: true

require "sidekiq"
require "json"

class BulkUploadJob
  include Sidekiq::Worker

  def perform(file_path, content_type, log_id = nil)
    log = log_id ? (BulkUploadLog.find(log_id) rescue nil) : nil
    started_at = Time.now.utc
    log&.set(started_at: started_at, status: "processing")

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
      body.each_line.map(&:strip).reject(&:empty?).map { |line| JSON.parse(line) }
    end
  end

  def process_record(json_text)
    if AppHelper.retail_servers.include?(json_text["server"])
      logger.warn "BulkUploadJob: skipping retail server character #{json_text["name"].inspect} on #{json_text["server"].inspect}"
      return :skipped
    end

    json_text.delete("key")

    name = json_text["name"]
    server = json_text["server"]
    allegiance_name = json_text["allegiance_name"]

    if json_text.key?("server_population")
      server_pop = json_text.delete("server_population")
      PlayerCount.where(server: server).find_one_and_update({ "$set" => { count: server_pop } }, upsert: true)
    end

    if json_text.key?("birth")
      json_text["birth"] = CharacterHelper.parse_birth(json_text["birth"])
    end

    if json_text.dig("patron", "name") == "??"
      logger.warn "BulkUploadJob: skipping #{name.inspect} on #{server.inspect} due to malformed patron name"
      return :skipped
    end

    return :skipped if name.nil? || server.nil?

    character = Character.unscoped.find_or_create_by(name: name, server: server)
    character.assign_attributes(json_text)
    character[:archived] = false if character[:archived]
    character.location = nil unless json_text["location"]
    character.monarch  = nil unless json_text["monarch"]
    character.patron   = nil unless json_text["patron"]
    character.vassals  = nil unless json_text["vassals"]

    character.save!

    Allegiance.find_or_create_by(server: server, name: allegiance_name) if allegiance_name

    :processed
  rescue => e
    logger.error "BulkUploadJob: error processing #{json_text["name"].inspect}: #{e}"
    :error
  end
end
