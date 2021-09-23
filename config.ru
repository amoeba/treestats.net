require "./app"

if ENV["RACK_ENV"] == "production"
  require 'sentry-ruby'

  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [:sentry_logger, :http_logger]
  end

  use Sentry::Rack::CaptureExceptions
end

map TreeStats.assets_prefix do
  run TreeStats.sprockets
end

map "/" do
  run TreeStats
end
