module Sinatra
  module TreeStats
    module Routing
      module Dashboards
        def self.registered(app)
          app.get('/dashboard/uploads_latest') do
            @latest = Character.desc(:updated_at)
                               .limit(10)
                               .only(:name, :server, :updated_at)

            if request.env['HTTP_HX_REQUEST'] == 'true'
              haml :_dashboard_uploads_latest, layout: false
            else
              haml :_dashboard_uploads_latest
            end
          end
        end
      end
    end
  end
end
