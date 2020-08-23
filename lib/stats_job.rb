require 'resque'
require 'resque/errors'
require 'redis'

require './helpers/stats_helper'

class StatsJob
  @queue = :default

  def self.perform
    puts "StatsJob.perform"

    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    redis.set('stats:attributes', Marshal.dump(StatsHelper::CharacterStats.sum_of_attributes.to_json))
    redis.set('stats:heritage', Marshal.dump(StatsHelper::CharacterStats.count_of_heritage.to_json))
    redis.set('stats:genders', Marshal.dump(StatsHelper::CharacterStats.count_of_genders.to_json))
    redis.set('stats:ranks', Marshal.dump(StatsHelper::CharacterStats.count_of_ranks.to_json))
    redis.set('stats:levels', Marshal.dump(StatsHelper::CharacterStats.count_of_levels.to_json))
    redis.set('stats:builds', Marshal.dump(StatsHelper::CharacterStats.sum_of_builds.to_json))
    redis.set('stats:levelfreq', Marshal.dump(StatsHelper::CharacterStats.frequency_of_levels.to_json))
  end
end
