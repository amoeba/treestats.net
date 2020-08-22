require 'clockwork'
require 'resque'
require 'uri'

# require './app.rb'
require File.expand_path('../query_cache_job', __FILE__)
require File.expand_path('../stats_job', __FILE__)

redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
uri = URI.parse(redis_url)
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

module Clockwork
  handler { |job|
    Resque.enqueue(job)
  }

  every 5.minutes, QueryCacheJob
  every 1.hours, StatsJob
end
