module Sinatra
  module TreeStats
    module Routing
      module Admin
        def self.registered(app)
          app.get "/admin/logs" do
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
