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

            # Query for the historical data
            keys = redis.keys("pc:max:*").sort
            result = {}

            keys.each do |key|
              tokens = key.split(":")
              server = tokens[2]
              date = tokens[3]

              key = "pc:max:#{server}:#{date}"

              result[server] ||= {}
              result[server][date] = redis.get(key)
            end

            result.to_json
          end

          app.get '/player_counts-latest.json' do
            content_type :json

            result = []

            servers = %w[Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb]
            servers.each do |server|
              latest = PlayerCount.where(server: server).desc(:created_at).limit(1)
              first_result = latest.to_a.first
              result << { 'server' => server, 'count' => first_result['c'], 'date' => first_result['c_at']}
            end

            JSON.pretty_generate(result)
          end
        end
      end
    end
  end
end
