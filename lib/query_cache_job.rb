require 'resque'
require 'resque/errors'
require 'redis'

require './helpers/query_helper'
require './helpers/player_counts_helper'

class QueryCacheJob
  @queue = :default

  def self.perform
    start = Time.now
    id = start.to_i

    puts "QueryCacheJob(#{id}).perform called"

    # Setup
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    # Cache queries
    redis.set("dashboard-latest-counts", Marshal.dump(QueryHelper.dashboard_latest_counts))
    redis.set("dashboard-total-uploaded", Marshal.dump(QueryHelper.dashboard_total_uploaded))
    redis.set("servers-with-counts", Marshal.dump(ServerHelper.servers_with_counts))

    puts "QueryCacheJob(#{id}) finished in #{Time.now - start} seconds"
  end
end
