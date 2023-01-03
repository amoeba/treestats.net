module Sinatra
  module TreeStats
    module Routing
      module Dashboards
        def self.registered(app)
          app.get('/dashboard/uploads_latest') do
            @latest = Character.desc(:updated_at)
                               .limit(10)
                               .only(:name, :server, :updated_at)

            haml :_dashboard_uploads_latest, layout: false
          end
        end
      end
    end
  end
end
