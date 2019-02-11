module Sinatra
  module TreeStats
    module Routing
      module General        
        def self.registered(app)
          app.get '/' do
            @latest_counts = PlayerCount.collection.aggregate([
              {
                "$match" => {
                  # "c_at" => {
                  #   "$gte" => Date.today - 30
                  # },
                  "s" => {
                    "$in" => AppHelper.servers
                  }
                }
              },
              {
                "$group" =>
                  {
                    "_id" => "$s",
                    "count" => {
                      "$last" => "$c"
                    },
                    "created_at" => {
                      "$last" => "$c_at"
                    }
                  }
              },
              {
                "$project" => {
                  "_id": 0,
                  "server": "$_id",
                  "count": "$count",
                  "date": "$created_at"
                }
              },
              {
                "$sort" => {
                  "c_at" => 1
                }
              }
            ])

            @latest = Character.desc(:updated_at)
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

          app.get "/servers/?" do
            @other_servers = Character.where(server: { '$nin' => AppHelper.retail_servers}).distinct(:server)

            # Filter out some servers
            @other_servers = @other_servers.reject { |n| n.downcase.include? "pea" or n.downcase.include? "phat"}

            haml :servers
          end

          app.get '/characters/?' do
            @characters = Character.where(:attribs.exists => true)
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
