require 'resque'
require 'resque/errors'
require 'redis'

require './helpers/stats_helper'

class StatsJob
  @queue = :default

  def self.perform
    puts "Stats job perform method"

    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    attributes = StatsHelper::CharacterStats.sum_of_attributes
    redis.set('stats:attributes', attributes.to_json)

    races = StatsHelper::CharacterStats.count_of_races
    redis.set('stats:races', races.to_json)

    genders = StatsHelper::CharacterStats.count_of_genders
    redis.set('stats:genders', genders.to_json)

    ranks = StatsHelper::CharacterStats.count_of_ranks
    redis.set('stats:ranks', ranks.to_json)

    levels = StatsHelper::CharacterStats.count_of_levels
    redis.set('stats:levels', levels.to_json)
  end
end
