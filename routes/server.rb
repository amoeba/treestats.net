module Sinatra
  module TreeStats
    module Routing
      module Server
        def self.registered(app)
          app.get "/servers/?" do
            request.accept.each do |type|
              case type.to_s
              when 'application/json'
                redis_key = "server-counts-with-json"

                if !redis.exists(redis_key)
                  result = ServerHelper.servers_with_counts.to_json
                  redis.setex(redis_key, 300, result)

                  halt result
                else
                  halt redis.get(redis_key)
                end

                halt
              when 'text/html'
                @servers = ServerHelper.server_details
                halt haml :servers
              end
            end

            error 406
          end

          app.get '/:server/?' do |server|
            @characters = Character.where(server: server)
                                   .desc(:updated_at).limit(100)
                                   .only(:name, :server, :updated_at)

            haml :server
          end

          app.get '/:server/:name.json' do |s,n|
            cross_origin

            begin
              @character = Character.unscoped.find_by(server: s, name: n)
            rescue Mongoid::Errors::DocumentNotFound
              not_found
            end

            content_type 'application/json'
            JSON.pretty_generate(@character.serializable_hash({}).tap {|h| h.delete("id")})
          end

          app.get '/:server/:name/?' do |s,n|
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
