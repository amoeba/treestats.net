module Sinatra
  module TreeStats
    module Routing
      module Chain
        def self.registered(app)
          app.get '/chain/:server/:name?' do |server, name|
            content_type :json

            character = Character.only(:name, :server)
                                 .find_by(server: server, name: name)

            return "{}" if character.nil?

            AllegianceChain.new(server, name).get_chain.to_json
          end
        end
      end
    end
  end
end
