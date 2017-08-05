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

            # Get max counts by date & server
            result = PlayerCount.collection.aggregate([
              { 
                "$group" => {
                  "_id" => {
                    "s" => "$s",
                    "date" => {
                      "$dateToString" => {
                        "format" => "%Y%m%d",
                        "date" => "$c_at"
                      }
                    }
                  },
                  "max" => { "$max" => "$c" }
                }
              },
              "$sort" => { "_id.date" => 1}
            ])

            # Restructure result for better JSON shape
            pops = {}

            result.each do |r|
              pops[r["_id"]["s"]] ||= []
              pops[r["_id"]["s"]] << { 
                :date => r["_id"]["date"],
                :count => r["max"] 
              }
            end

            pops.to_json
          end

          app.get '/player_counts-latest.json' do
            content_type :json

            result = []

            # servers = %w[Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb Megaduck Ducktide YewThaw YewTide]
            servers = AppHelper.servers
            puts servers
            servers.each do |server|
              latest = PlayerCount.where(server: server)
                                  .desc(:created_at)
                                  .limit(1)

              # Move on if no player counts were recorded
              next if latest.count == 0

              first_result = latest.to_a.first
              result << { 
                'server' => server, 
                'count' => first_result['c'], 
                'date' => first_result['c_at'],
                'age' => relative_time(first_result['c_at'])
              }
            end

            JSON.pretty_generate(result)
          end
        end
      end
    end
  end
end
