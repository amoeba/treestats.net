module Sinatra
  module TreeStats
    module Routing
      module Admin
        def self.registered(app)
          app.get "/admin/logs" do
            auth = Rack::Auth::Basic::Request.new(request.env)
            expected_user = ENV.fetch("SIDEKIQ_WEB_USERNAME", "admin")
            expected_pass = ENV["SIDEKIQ_WEB_PASSWORD"]

            unless expected_pass &&
                   auth.provided? && auth.basic? &&
                   auth.credentials == [expected_user, expected_pass]
              response.headers["WWW-Authenticate"] = 'Basic realm="Admin"'
              halt 401, JSON.generate({ "error" => "unauthorized" })
            end

            @logs = BulkUploadLog.all.desc(:submitted_at).limit(100)

            if request.preferred_type("text/html", "application/json").to_s == "application/json"
              content_type :json
              JSON.generate(@logs.map { |log|
                {
                  id:              log.id.to_s,
                  status:          log.status,
                  account_id:      log.account_id,
                  submitted_at:    log.submitted_at&.iso8601,
                  started_at:      log.started_at&.iso8601,
                  completed_at:    log.completed_at&.iso8601,
                  duration_ms:     log.duration_ms,
                  record_count:    log.record_count,
                  processed_count: log.processed_count,
                  skipped_count:   log.skipped_count,
                  error_count:     log.error_count,
                  content_type:    log.content_type,
                }
              })
            else
              haml :admin_logs, layout: :admin_layout
            end
          end
        end
      end
    end
  end
end
