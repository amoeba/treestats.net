module Sinatra
  module TreeStats
    module Routing
      module General
        def self.registered(app)
          app.get '/' do
            # Total uploads
            @total_uploads = redis
              .keys("uploads:daily:*")
              .collect { |k| redis.get(k) }
              .reduce(:+)

            # Latest counts
            if !redis.exists("dashboard-latest-counts")
              @latest_counts = []
            else
              @latest_counts = Marshal.restore(redis.get("dashboard-latest-counts"))
            end

            # Total Uploaded
            if !redis.exists("dashboard-total-uploaded")
              @total_uploaded = []
            else
              @total_uploaded = Marshal.restore(redis.get("dashboard-total-uploaded"))
            end

            # Latest uploads
            @latest = Character.desc(:updated_at)
              .limit(10)
              .only(:name, :server, :updated_at)

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
            @characters = Character.unscoped
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
