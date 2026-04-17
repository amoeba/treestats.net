# frozen_string_literal: true

require "sidekiq"
require "json"

class BulkUploadJob
  include Sidekiq::Worker

  def perform(file_path, content_type)
    body = File.read(file_path)
    records = parse_records(body, content_type)

    logger.info "BulkUploadJob: starting, #{records.length} records"

    records.each { |record| process_record(record) }

    logger.info "BulkUploadJob: done, #{records.length} records processed"
  ensure
    File.delete(file_path) if file_path && File.exist?(file_path)
    BulkUploadHelper.decrement_inflight!
  end

  private

  def parse_records(body, content_type)
    if content_type.include?("application/json")
      JSON.parse(body)
    else
      # NDJSON: one JSON object per line
      body.each_line.map(&:strip).reject(&:empty?).map { |line| JSON.parse(line) }
    end
  end

  def process_record(json_text)
    # Skip retail server characters
    if AppHelper.retail_servers.include?(json_text["server"])
      logger.warn "BulkUploadJob: skipping retail server character #{json_text["name"].inspect} on #{json_text["server"].inspect}"
      return
    end

    json_text.delete("key")

    name = json_text["name"]
    server = json_text["server"]
    allegiance_name = json_text["allegiance_name"]

    # Extract server_population if present
    if json_text.key?("server_population")
      server_pop = json_text.delete("server_population")
      PlayerCount.create(server: server, count: server_pop)
    end

    # Parse birth field
    if json_text.key?("birth")
      json_text["birth"] = CharacterHelper.parse_birth(json_text["birth"])
    end

    # Skip records with malformed patron name
    if json_text.dig("patron", "name") == "??"
      logger.warn "BulkUploadJob: skipping #{name.inspect} on #{server.inspect} due to malformed patron name"
      return
    end

    character = Character.unscoped.find_or_create_by(name: name, server: server)
    character.assign_attributes(json_text)
    character[:archived] = false if character[:archived]
    character.location = nil unless json_text["location"]
    character.monarch  = nil unless json_text["monarch"]
    character.patron   = nil unless json_text["patron"]
    character.vassals  = nil unless json_text["vassals"]

    # save! raises on failure, which fails the job and lets Sidekiq retry
    character.save!

    Allegiance.find_or_create_by(server: server, name: allegiance_name) if allegiance_name
  end
end
