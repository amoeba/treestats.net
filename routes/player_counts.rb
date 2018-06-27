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

            if !redis.exists("latest-counts")
              puts "PLAYER_COUNTS_LATEST-SETEX"
              result = latest_player_counts
              redis.setex("latest-counts", 60, result)

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
