module Sinatra
  module TreeStats
    module Routing
      module General        
        def self.registered(app)
          app.get '/' do
            return "TreeStats is currently in upload-only mode due to a system failure. It doesn't look like any data was lost at this point but I'm currently traveling. Uploads to TreeStats.net via the plugin will continue to work. I'll be back on July 5th, 2018 and will bring the full site up then. Sorry for the inconvenience!"
            
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

            haml :index
          end

          app.get "/download/?" do
            haml :download
          end

          # app.get '/graphs/?' do
          #   haml :graphs
          # end

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
