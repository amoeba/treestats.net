module Sinatra
  module TreeStats
    module Routing
      module General
        def self.registered(app)
          app.get '/' do
            # @latest = Character.where(:attribs.exists => true,
            #                           :archived => false)
            #                           .desc(:updated_at)
            #                           .limit(10)
            #                           .only(:name, :server)
            # #@level
            @latest = []
            haml :index
          end

          app.get "/download/?" do
            haml :download
          end

          app.get '/graphs/?' do
            haml :graphs
          end

          app.get "/servers/?" do
            haml :servers
          end

          app.get '/characters/?' do
            @characters = Character.where(:attribs.exists => true,
                                          :archived => false)
                                   .desc(:updated_at)
                                   .limit(100).only(:name, :server)

            haml :characters
          end

          app.get '/api/?' do
            haml :api
          end

          app.get '/about/?' do
            haml :about
          end
        end
      end
    end
  end
end
