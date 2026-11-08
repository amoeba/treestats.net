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
  # A poll target. `fallback_url` is only set for discovered roots, which are
  # tried over HTTP first and HTTPS second.
  Target = Struct.new(:url, :fallback_url)

  def self.config
    YAML.safe_load_file(File.expand_path("../config/polling_targets.yml", __dir__)) || {}
  end

  # Servers may serve their info document at the root of the public game
  # endpoint, e.g. http://play.example.net:9000/. That is the default target.
  def self.discovered_targets
    server_list.each_with_object({}) do |server, result|
      name = server[:name].to_s
      host = server[:host].to_s.strip
      port = server[:port].to_s.strip
      next if name.empty? || host.empty? || port.empty?

      result[name] = Target.new(
        url: "http://#{host}:#{port}/",
        fallback_url: "https://#{host}:#{port}/"
      )
    end
  end

  # Polling is opt-in. Servers enabled in config/polling_targets.yml are
  # polled; an omitted URL means the standard root endpoint from data/servers.rb,
  # tried over HTTP first with HTTPS as a fallback. Explicit URLs are used as-is.
  def self.targets
    targets_from(config.fetch("targets", {}) || {})
  end

  def self.targets_from(configured)
    roots = discovered_targets
    known_servers = server_list.map { |server| server[:name].to_s }
    configured.each_with_object({}) do |(server, settings), result|
      raise Error, "invalid target name for #{server.inspect}" unless server.is_a?(String) && !server.strip.empty?
      raise Error, "invalid target settings for #{server}" unless settings.is_a?(Hash)

      enabled = settings["enabled"]
      raise Error, "enabled must be true or false for #{server}" unless [true, false].include?(enabled)
      next unless enabled

      url = settings["url"]
      raise Error, "invalid target URL for #{server}" unless url.nil? || url.is_a?(String)
      raise Error, "unknown polling target #{server.inspect}; add it to data/servers.rb" unless known_servers.include?(server)

      result[server] = if url
        Target.new(url: url)
      else
        roots[server] || raise(Error, "polling target #{server.inspect} has no host or port in data/servers.rb; give a URL")
      end
    end
  end

  def self.server_list
    require_relative "../data/servers"
    SERVERS
  rescue LoadError
    []
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
