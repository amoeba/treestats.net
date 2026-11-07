# frozen_string_literal: true

# Sidekiq process entry point.
# Loaded via: bundle exec sidekiq -r ./lib/sidekiq_boot.rb
#
# Intentionally does NOT load app.rb — no Sinatra stack, no asset pipeline,
# no Resque setup. This file is the parallel track.

# Sentry must be initialized before sentry-sidekiq is required
if ENV["RACK_ENV"] == "production"
  require "sentry-ruby"
  require "sentry-sidekiq"

  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.traces_sample_rate = 0.01
    config.release = ENV["GIT_REV"] if ENV["GIT_REV"]
  end
end

require "bundler/setup"
Bundler.require(:default)

# Mongoid
Mongoid.load!(File.expand_path("../config/mongoid.yml", __dir__))
Mongo::Logger.logger.level = ::Logger::INFO

# Standalone worker model dependencies (app.rb is intentionally not loaded).
require_relative "../models/player_count"

# Job files
require_relative "probe_job"
require_relative "population_poller"
require_relative "sidekiq_job_metadata_middleware"

redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"

Sidekiq.configure_server do |config|
  config.redis = {url: redis_url}
  config.server_middleware do |chain|
    chain.add SidekiqJobMetadataMiddleware
  end

  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash(
      "probe_job" => {
        "cron" => "*/5 * * * *",
        "class" => "ProbeJob"
      },
      "population_poll_dispatch" => {
        "cron" => "*/15 * * * *",
        "class" => "DispatchPopulationPollsJob"
      }
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = {url: redis_url}
end
