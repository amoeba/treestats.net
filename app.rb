# Initialize Sentry as soon as possible as recommended
if ENV['RACK_ENV'] == 'production'
  require 'sentry-ruby'
  require 'sentry-resque'

  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.traces_sample_rate = 0.01

    if ENV['GIT_REV']
      config.release = ENV['GIT_REV']
    end
  end
end

# Regular app startup begins now
require 'bundler/setup'
Bundler.require(:default)

require 'sinatra/redis'
require 'sinatra/cross_origin'

PumaWorkerKiller.enable_rolling_restart if ENV['RACK_ENV'] == 'production'

%w[models routes helpers].each do |d|
  Dir["./#{d}/*.rb"].each { |file| require file }
end

%w[
  lib/clock.rb
  lib/graph_job.rb
  lib/query_cache_job.rb
  lib/stats_job.rb
].each { |file| require_relative file }

require_relative 'lib/asset_server'

class TreeStats < Sinatra::Base
  configure :production do
    use Sentry::Rack::CaptureExceptions
  end

  set :root, File.dirname(__FILE__)

  set :assets_prefix, '/assets'
  set(:asset_server) { AssetServer.new(root) }

  # Explicitly register Sinatra::Redis so the method `redis` is available
  # to other parts of our application like routes
  register Sinatra::Redis

  # Routes (alpha order)
  register Sinatra::TreeStats::Routing::Accounts
  register Sinatra::TreeStats::Routing::Allegiances
  register Sinatra::TreeStats::Routing::Chain
  register Sinatra::TreeStats::Routing::General
  register Sinatra::TreeStats::Routing::PlayerCounts
  register Sinatra::TreeStats::Routing::Rankings
  register Sinatra::TreeStats::Routing::Search
  register Sinatra::TreeStats::Routing::Stats
  register Sinatra::TreeStats::Routing::Titles
  register Sinatra::TreeStats::Routing::Upload
  register Sinatra::TreeStats::Routing::Dashboards

  # CORS
  register Sinatra::CrossOrigin

  # Load server route last because it has catch-alls
  register Sinatra::TreeStats::Routing::Server

  configure do
    # Turn on logging
    enable :logging

    # Disable Rack::Protection — Something started causing lots of 403s on GET
    # and POST routes and this is the only thing I can think of that might be
    # causing.
    set :protection, false

    # Mongoid
    Mongoid.load!('./config/mongoid.yml')
    Mongo::Logger.logger.level = ::Logger::INFO

    # Redis
    redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379'
    uri = URI.parse(redis_url)
    set :redis, redis_url

    # Resque
    Resque.redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)

    # CORS
    enable :cross_origin
  end

  helpers do
    include Sinatra::TreeStats::AssetHelper
    include RequestHelper
  end

  configure :production do
    require 'newrelic_rpm'
  end

  not_found do
    haml :not_found
  end
end
