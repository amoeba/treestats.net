require "securerandom"
require "json"

module Sinatra
  module TreeStats
    module Routing
      module BulkUpload
        def self.registered(app)
          app.post "/characters" do
            body_str = request.body.read
            content_type_header = request.content_type.to_s

            unless BulkUploadHelper.valid_signature?(request, body_str)
              status 403
              content_type :json
              return JSON.generate({ "error" => "invalid signature" })
            end

            if BulkUploadHelper.over_rate_limit?(redis, request.ip)
              status 429
              content_type :json
              return JSON.generate({ "error" => "rate limit exceeded" })
            end

            if BulkUploadHelper.over_inflight_limit?(redis)
              status 503
              content_type :json
              return JSON.generate({ "error" => "too many jobs in flight, try again later" })
            end

            file_path = "/tmp/bulk_upload_#{SecureRandom.uuid}"

            begin
              File.write(file_path, body_str)
            rescue => e
              status 500
              content_type :json
              return JSON.generate({ "error" => "failed to save upload" })
            end

            BulkUploadJob.perform_async(file_path, content_type_header)
            BulkUploadHelper.increment_inflight!(redis)

            status 202
            content_type :json
            JSON.generate({ "status" => "queued" })
          end
        end
      end
    end
  end
end
