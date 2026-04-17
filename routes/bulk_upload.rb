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

            record_count = if content_type_header.include?("application/json")
              parsed = JSON.parse(body_str) rescue nil
              parsed.is_a?(Array) ? parsed.length : 1
            else
              body_str.each_line.count { |l| !l.strip.empty? }
            end

            log = BulkUploadLog.create!(
              account_id:   BulkUploadHelper.account_id_from_request(request),
              submitted_at: Time.now.utc,
              record_count: record_count,
              content_type: content_type_header,
              status:       "queued"
            )

            file_path = "/tmp/bulk_upload_#{SecureRandom.uuid}"

            begin
              File.write(file_path, body_str)
            rescue => e
              log.set(status: "failed")
              status 500
              content_type :json
              return JSON.generate({ "error" => "failed to save upload" })
            end

            BulkUploadHelper.increment_inflight!(redis)
            begin
              BulkUploadJob.perform_async(file_path, content_type_header, log.id.to_s)
            rescue => e
              BulkUploadHelper.decrement_inflight!(redis)
              raise
            end

            status 202
            content_type :json
            JSON.generate({ "status" => "queued", "log_id" => log.id.to_s })
          end
        end
      end
    end
  end
end
