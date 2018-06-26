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

            if params[:servers] && params[:servers] == "retail"
              servers = AppHelper.retail_servers
            else
              servers = AppHelper.servers
            end

            # Get max counts by date & server
            # TODO: Filter to only allowed servers
            result = PlayerCount.collection.aggregate([
              {
                "$match" => {
                  "c_at" => {
                    "$gte" => Date.today - 120
                  },
                  "s" => {
                    "$in" => servers
                  }
                }
              },
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
              "$sort" => { 
                "_id.date" => 1 
              }
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

            latest_counts = PlayerCount.collection.aggregate([
              {
                "$group" =>
                  {
                    "_id" => "$s",
                    "count" => {
                      "$last" => "$c"
                    },
                    "created_at" => {
                      "$last" => "$c_at"
                    }
                  }
              },
              {
                "$project" => {
                  "_id": 0,
                  "server": "$_id",
                  "count": "$count",
                  "date": "$created_at"
                }
              },
              { 
                "$sort" => {
                  "c_at" => 1
                } 
              }
            ])
         
            latest_counts = latest_counts.to_a
            latest_counts.each_with_index do |item,i|
              latest_counts[i]["age"] = relative_time(item["date"])
            end

            JSON.pretty_generate(latest_counts)
          end
        end
      end
    end
  end
end
