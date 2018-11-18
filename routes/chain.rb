module Sinatra
  module TreeStats
    module Routing
      module Chain
        def self.registered(app)
          app.get '/chain/:server/:name?' do |server, name|
            content_type :json

            begin
              character = Character.unscoped
                                   .only(:name, :server)
                                   .find_by(server: server, name: name)
            rescue Mongoid::Errors::DocumentNotFound
              not_found
            end

            AllegianceChain.new(server, name).get_chain.to_json
          end
        end
      end
    end
  end
end
