require "sinatra/redis"

module Sinatra
  module TreeStats
    module Routing
      module PlayerCounts
        def self.registered(app)
          app.get "/player_counts/?" do
            @servers = ServerHelper.all_servers
            @retail_servers = ServerHelper.retail_servers
            @private_servers = ServerHelper.servers

            @current = params[:servers]
            @range = params[:range]

            # Add in ?servers filter to API call if present
            @player_counts_url = "/player_counts.json"

            if params
              out = {}

              if params[:servers]
                out[:servers] = params[:servers]
              end

              if params[:range]
                out[:range] = params[:range]
              end

              @player_counts_url += "?#{out.to_query}"
            end

            haml :player_counts
          end

          app.get "/player_counts.json" do
            content_type :json

            @servers = ServerHelper.all_servers
            @retail_servers = ServerHelper.retail_servers
            @private_servers = ServerHelper.servers

            # servers
            servers = params[:servers]

            # Nil-ify empty value
            if servers && servers.strip.length == 0
              servers = nil
            end

            if servers && servers != "All"
              # FIXME: Comment this out for now so players can request data from
              #        unlisted servers. This is the case for private servers that
              # no longer operate

              # params[:servers].split(",").each do |server|
              #   unless ServerHelper.all_servers.include?(server)
              #     halt 400, "Invalid query parameters: #{server} is not a valid server name"
              #   end
              # end

              # ENDFIXME

              # Special case: Replace keywords "retail" and "emulator" with their
              # respective servers
              servers = servers.sub("retail", @retail_servers.join(","))
              servers = servers.sub("emulator", @private_servers.join(","))

              servers = servers.split(",")
            end

            # range
            ranges = %w[3mo 6mo 1yr All]
            range = params[:range]

            # Nil-ify empty value
            if range && range.strip.length == 0
              range = nil
            end

            if range
              unless ranges.include?(range)
                halt 400, "Invalid query parameters: #{range} is not a valid range"
              end
            end

            range = range || "3mo"

            # set up a key for redis caching
            redis_key = if servers
              "player-counts-#{servers.join("-")}-#{range}"
            else
              "player-counts-All-#{range}"
            end

            if !redis.exists?(redis_key)
              result = player_counts(servers, range)
              redis.setex(redis_key, 360, result)

              return result
            else
              return redis.get(redis_key)
            end
          end

          app.get "/player_counts-latest.json" do
            content_type :json

            if !redis.exists?("latest-counts")
              result = latest_player_counts
              redis.setex("latest-counts", 360, result)

              return result
            else
              return redis.get("latest-counts")
            end
          end

          app.get "/player_counts/:server.json" do |server|
            content_type :json

            count = PlayerCount.where(s: server).desc(:c_at).limit(1).first
            not_found if count.nil?

            cleaned_count = count.serializable_hash({}).tap { |h| h.delete("id") }.tap { |h| h["age"] = AppHelper.relative_time(h["created_at"]) }
            JSON.pretty_generate(cleaned_count)
          end
        end
      end
    end
  end
end
