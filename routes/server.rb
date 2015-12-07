module Sinatra
  module TreeStats
    module Routing
      module Server
        def self.registered(app)
          app.get '/:server/?' do |server|
            @characters = Character.where(server: server).where(:attribs.exists => true).desc(:updated_at).limit(100)

            haml :server
          end

          app.get '/:server/:name.json' do |s,n|
            begin
              @character = Character.find_by(server: s, name: n)
            rescue Mongoid::Errors::DocumentNotFound
              not_found
            end

            content_type 'application/json'
            JSON.pretty_generate(@character.serializable_hash({}).tap {|h| h.delete("id")})
          end

          app.get '/:server/:name/?' do |s,n|
            begin
              @character = Character.find_by(server: s, name: n)
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
