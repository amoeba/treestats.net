require 'resque'
require 'resque/errors'
require 'redis'

require './helpers/query_helper'
require './helpers/player_counts_helper'

class QueryCacheJob
  @queue = :default

  def self.perform
    puts "QueryCacheJob.perform"

    # Setup
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    # Cache queries
    redis.set("dashboard-latest-counts", Marshal.dump(QueryHelper.dashboard_latest_counts))
    redis.set("dashboard-total-uploaded", Marshal.dump(QueryHelper.dashboard_total_uploaded))
    redis.set("player-counts", Marshal.dump(PlayerCountsHelper.player_counts))
    redis.set("latest-player-counts", Marshal.dump(PlayerCountsHelper.latest_player_counts))
  end
end
