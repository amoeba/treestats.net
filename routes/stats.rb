module Sinatra
  module TreeStats
    module Routing
      module Stats
        def self.registered(app)
          app.get '/stats/uploads/daily' do
            value = redis.keys "uploads:daily:*"

            result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(":")[2], :count => redis.get(v).to_i }}

            # Trim last result
            result = result[0..(result.size - 2)] if result.size > 1
            result.to_json
          end

          app.get '/stats/uploads/monthly' do
            value = redis.keys "uploads:monthly:*"

            result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(":")[2], :count => redis.get(v).to_i }}
            result.to_json
          end

          app.get '/stats/attributes' do
            value = StatsHelper::CharacterStats.sum_of_attributes
            value.to_json
          end

          app.get '/stats/genders' do
            value = StatsHelper::CharacterStats.count_of_genders
            value.to_json
          end

          app.get '/stats/ranks' do
            value = StatsHelper::CharacterStats.count_of_ranks
            value.to_json
          end

          app.get '/stats/levels' do
            # redis.get("stats:levels")
            value = StatsHelper::CharacterStats.count_of_levels
            value.to_json
          end

          app.get '/stats/races' do
            value = StatsHelper::CharacterStats.count_of_races
            value.to_json
          end

          app.get '/stats/sum_of_builds' do
            value = StatsHelper::CharacterStats.sum_of_builds
            value.to_json
          end
        end
      end
    end
  end
end
