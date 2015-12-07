require 'bundler/setup'
Bundler.require(:default)

require 'sinatra/base'
require 'sinatra/asset_pipeline'
require 'sinatra/redis'

%w[models routes lib helpers].each do |d|
  Dir["./#{d}/*.rb"].each { |file| require file }
end

class TreeStats < Sinatra::Base
  set :root, File.dirname(__FILE__)

  # helpers Sinatra::TreeStats::Helpers

  set :assets_precompile, %w(*.js *.scss *.css *.png)
  register Sinatra::AssetPipeline

  # Explicitly register Sinatra::Redis so the method `redis` is available
  # to other parts of our application like routes
  register Sinatra::Redis

  # Routes
  register Sinatra::TreeStats::Routing::Accounts
  register Sinatra::TreeStats::Routing::Allegiances
  register Sinatra::TreeStats::Routing::Chain
  register Sinatra::TreeStats::Routing::General
  register Sinatra::TreeStats::Routing::PlayerCounts
  register Sinatra::TreeStats::Routing::Rankings
  register Sinatra::TreeStats::Routing::Search
  register Sinatra::TreeStats::Routing::Stats
  register Sinatra::TreeStats::Routing::Upload
  # Load server route last because it has catch-alls
  register Sinatra::TreeStats::Routing::Server


  configure do
    # Mongoid
    Mongoid.load!("./config/mongoid.yml")

    # Redis
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    set :redis, redis_url

    # Resque
    Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end

  configure :production do
    require 'newrelic_rpm'
  end

  not_found do
    haml :not_found
  end
end
