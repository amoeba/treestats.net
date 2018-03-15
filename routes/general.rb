module Sinatra
  module TreeStats
    module Routing
      module General        
        def self.registered(app)
          app.get '/' do
            @latest = Character.where(:archived => false)
                                      .desc(:updated_at)
                                      .limit(10)
                                      .only(:name, :server, :updated_at)

            @servers = Character.collection.aggregate([
              { 
                "$match" => { 
                  "s" => { 
                    "$nin" => AppHelper.retail_servers 
                  }
                }
              },
              { 
                "$group" => {
                  "_id" => "$s",
                  "count" => { "$sum" => 1 }
                }
              },
              { 
                "$sort" => {
                  "count" => -1
                }
              },
              {
                "$limit": 10
              }
            ])

            puts AppHelper.servers

            haml :index
          end

          app.get "/download/?" do
            haml :download
          end

          app.get '/graphs/?' do
            haml :graphs
          end

          app.get "/servers/?" do
            @other_servers = Character.where(server: { '$nin' => AppHelper.all_servers}).distinct(:server)

            # Filter out some servers
            @other_servers = @other_servers.reject { |n| n.downcase.include? "pea" or n.downcase.include? "phat"}

            haml :servers
          end

          app.get '/characters/?' do
            @characters = Character.where(:attribs.exists => true,
                                          :archived => false)
                                   .desc(:updated_at)
                                   .limit(100)
                                   .only(:name, :server)

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
