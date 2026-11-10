module Sinatra
  module TreeStats
    module Routing
      module Server
        def self.registered(app)
          app.get "/servers/?" do
            redis_key = "servers-with-counts"

            @servers = if !redis.exists?(redis_key)
              ServerHelper.servers_with_counts
            else
              Marshal.restore(redis.get(redis_key))
            end

            request.accept.each do |type|
              case type.to_s
              when "application/json"
                content_type :json

                halt JSON.pretty_generate(@servers)
              else
                @softwares = ServerHelper.softwares

                halt haml :servers
              end
            end

            error 406
          end

          app.get "/servers.json" do
            content_type :json

            redis_key = "servers-with-counts"

            servers = if !redis.exists?(redis_key)
              ServerHelper.servers_with_counts
            else
              Marshal.restore(redis.get(redis_key))
            end

            return JSON.pretty_generate(servers)
          end

          # Unlisted diagnostic view; keep raw observations separate from the
          # existing aggregated API and its backwards-compatible serialization.
          app.get "/servers/:server/player-counts/?" do |server|
            headers "X-Robots-Tag" => "noindex, nofollow"
            @server = server
            @observations_url = "/servers/#{URI.encode_www_form_component(server).gsub('+', '%20')}/player-counts.json"
            haml :server_player_counts
          end

          app.get "/servers/:server/player-counts.json" do |server|
            headers "X-Robots-Tag" => "noindex, nofollow"
            content_type :json
            now = Time.now.utc
            since = now - 14 * 24 * 60 * 60
            observations = PlayerCount.where(s: server, :c_at.gte => since, :c_at.lte => now)
              .asc(:c_at).map do |observation|
                {
                  time: observation.created_at.utc.iso8601(3),
                  count: observation.count,
                  source: observation.effective_source
                }
              end
            JSON.generate({start: since.iso8601(3), end: now.iso8601(3), observations: observations})
          end

          app.get "/:server/?" do |server|
            @characters = Character.where(server: server)
              .desc(:updated_at).limit(25)
              .only(:name, :server, :updated_at)
            @uploaded = Character.unscoped.where(server: server).count

            @online = PlayerCount.where(s: server).desc(:c_at).limit(1).first
            @details = ServerHelper.server_details.filter { |s| s[:name] == server }.first
            @softwares = ServerHelper.softwares

            haml :server
          end

          app.get "/:server/:name.json" do |s, n|
            cross_origin

            begin
              @character = Character.unscoped.find_by(server: s, name: n)
            rescue Mongoid::Errors::DocumentNotFound
              not_found
            end

            content_type "application/json"
            @character.to_json
          end

          app.get "/:server/:name.text" do |s, n|
            cross_origin

            begin
              @character = Character.unscoped.find_by(server: s, name: n)
            rescue Mongoid::Errors::DocumentNotFound
              not_found
            end

            content_type "text/plain"
            haml :character_text, layout: false
          end

          app.get "/:server/:name/?" do |s, n|
            begin
              @character = Character.unscoped.find_by(server: s, name: n)
            rescue Mongoid::Errors::DocumentNotFound
              not_found
            end

            haml :character
          end
        end
      end
    end
  end
end
