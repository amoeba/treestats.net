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

            if !redis.exists("player-counts")
              return player_counts
            else
              return redis.get("player-counts")
            end
          end

          app.get '/player_counts-latest.json' do
            content_type :json

            if !redis.exists("latest-player-counts")
              return []
            else
              return redis.get("latest-player-counts")
            end
          end

          app.get '/player_counts/:server.json' do |server|
            content_type :json

            count = PlayerCount.where(s: server).desc(:c_at).limit(1).first
            not_found if count.nil?

            cleaned_count = count.serializable_hash({}).tap { |h| h.delete("id") }.tap { |h| h['age'] = AppHelper.relative_time(h["created_at"]) }
            JSON.pretty_generate(cleaned_count)
          end
        end
      end
    end
  end
end
