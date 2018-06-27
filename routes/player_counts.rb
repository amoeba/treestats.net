require 'sinatra/redis'

module Sinatra
  module TreeStats
    module Routing
      module PlayerCounts
        def self.registered(app)
          app.get '/player_counts/?' do
            haml :player_counts
          end

          app.get '/player_counts.json' do
            content_type :json

            redis_key = "player-counts"
            
            if !redis.exists(redis_key)
              puts "PLAYER_COUNTS-SETEX"
              result = player_counts
              puts result
              redis.setex(redis_key, 60, result)

              return result
            else
              puts "PLAYER_COUNTS-CACHED"
              return redis.get(redis_key)
            end
          end

          app.get '/player_counts-latest.json' do
            content_type :json

            if !redis.exists("latest-counts")
              puts "PLAYER_COUNTS_LATEST-SETEX"
              result = latest_player_counts
              redis.setex("latest-counts", 300, result)

              return result
            else
              puts "PLAYER_COUNTS_LATEST-CACHED"
              return redis.get("latest-counts")
            end
          end

          app.get '/player_counts/:server.json' do |server|
            content_type :json

            count = PlayerCount.where(s: server).desc(:c_at).limit(1).first
            not_found if count.nil?

            cleaned_count = count.serializable_hash({}).tap { |h| h.delete("id") }.tap { |h| h['age'] = relative_time(h["created_at"]) }
            JSON.pretty_generate(cleaned_count)
          end
        end
      end
    end
  end
end
