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

            # Grab the latest counts from the raw data
            servers = %w[Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb]
            today = Time.now.utc.strftime("%Y%m%d")

            servers.each do |server|
              next unless result.has_key?(server.downcase)

              latest = PlayerCount.where(server: server).desc(:created_at).limit(1)
              result[server.downcase][today] = latest.to_a.first['c']
            end

            result.to_json
          end
        end
      end
    end
  end
end
