module Sinatra
  module TreeStats
    module Routing
      module General        
        def self.registered(app)
          app.get '/' do
            # Latest counts
            redis_key = "dashboard-latest-counts"

            if !redis.exists(redis_key)
              @latest_counts = QueryHelper.dashboard_latest_counts 
              redis.setex(redis_key, 300, Marshal.dump(@latest_counts))
            else
              @latest_counts = Marshal.restore(redis.get(redis_key))
            end   

            # Latest uploads
            @latest = Character.desc(:updated_at)
                               .limit(10)
                               .only(:name, :server, :updated_at)

            # Total Uploaded
            redis_key = "dashboard_total_uploaded"

            if !redis.exists(redis_key)
              @total_uploaded = QueryHelper.dashboard_total_uploaded 
              redis.setex(redis_key, 600, Marshal.dump(@total_uploaded))
            else
              @total_uploaded = Marshal.restore(redis.get(redis_key))
            end   

            haml :index
          end

          app.get "/download/?" do
            haml :download
          end

          app.get "/servers/?" do
            @other_servers = AppHelper.servers

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
