module Sinatra
  module TreeStats
    module Routing
      module Server
        def self.registered(app)
          app.get "/servers/?" do
            @servers = ServerHelper.server_details

            haml :servers
          end

          app.get "/servers.json" do
            content_type :json

            @servers = ServerHelper.server_details

            JSON.pretty_generate(@servers)
          end

          app.get '/:server/?' do |server|
            @characters = Character.where(server: server)
                                   .desc(:updated_at).limit(25)
                                   .only(:name, :server, :updated_at)
            @uploaded = Character.unscoped.where(server: server).count

            @online = PlayerCount.where(s: server).desc(:c_at).limit(1).first
            @details = ServerHelper.server_details.filter { |s| s[:name] == server }.first

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
