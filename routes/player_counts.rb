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

            keys = redis.keys("pc:mean:*").sort
            result = {}

            keys.each do |key|
              tokens = key.split(":")
              server = tokens[2]
              date = tokens[3]

              key = "pc:mean:#{server}:#{date}"

              result[server] ||= {}
              result[server][date] = redis.get(key)
            end

            result.to_json
          end
        end
      end
    end
  end
end
