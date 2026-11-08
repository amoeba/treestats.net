# frozen_string_literal: true

require "yaml"

# Polling configuration lives apart from the poll jobs so the web process can
# read targets and intervals without loading Sidekiq workers.
module DataPoller
  DEFAULT_INTERVAL = "15m"
  INTERVAL_UNITS = {
    "m" => 60, "min" => 60, "mins" => 60, "minute" => 60, "minutes" => 60,
    "h" => 3600, "hr" => 3600, "hrs" => 3600, "hour" => 3600, "hours" => 3600,
    "d" => 86_400, "day" => 86_400, "days" => 86_400
  }.freeze
  INTERVAL_PATTERN = /\A\s*(\d+)\s*([a-z]+)\s*\z/i
  class Error < StandardError; end

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
end
