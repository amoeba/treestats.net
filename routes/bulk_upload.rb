require "securerandom"
require "json"

module Sinatra
  module TreeStats
    module Routing
      module BulkUpload
        def self.registered(app)
          app.post "/characters" do
            max_bytes = (ENV["BULK_UPLOAD_MAX_BYTES"] || (10 * 1024 * 1024)).to_i
            body_str = request.body.read(max_bytes + 1)
            if body_str.length > max_bytes
              status 413
              content_type :json
              return JSON.generate({ "error" => "request body too large" })
            end
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

            record_count = if content_type_header.include?("application/json")
              parsed = JSON.parse(body_str) rescue nil
              parsed.nil? ? 0 : (parsed.is_a?(Array) ? parsed.length : 1)
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

            unless BulkUploadHelper.try_increment_inflight!(redis)
              log.set(status: "rejected")
              status 503
              content_type :json
              return JSON.generate({ "error" => "too many jobs in flight, try again later" })
            end

            # NOTE: web and worker processes must share the same filesystem for
            # this path to be accessible. Single-host deployments only.
            file_path = "/tmp/bulk_upload_#{SecureRandom.uuid}"

            begin
              File.write(file_path, body_str)
            rescue => e
              BulkUploadHelper.decrement_inflight!(redis)
              log.set(status: "failed")
              status 500
              content_type :json
              return JSON.generate({ "error" => "failed to save upload" })
            end

            begin
              BulkUploadJob.perform_async(file_path, content_type_header, log.id.to_s)
            rescue => e
              BulkUploadHelper.decrement_inflight!(redis)
              File.delete(file_path) if File.exist?(file_path)
              log.set(status: "failed")
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
