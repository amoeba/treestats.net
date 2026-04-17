require "openssl"

module BulkUploadHelper
  SIGNATURE_HEADER = "HTTP_X_TREESTATS_UPLOAD_SIGNATURE"
  INFLIGHT_KEY     = "bulk_upload:inflight"
  RATE_LIMIT_KEY   = "bulk_upload:ratelimit"

  def self.valid_signature?(request, body)
    secret = ENV["BULK_UPLOAD_SECRET"]
    return true if secret.nil? || secret.empty?

    header = request.env[SIGNATURE_HEADER]
    return false if header.nil?

    prefix = "sha256="
    return false unless header.start_with?(prefix)

    provided = header[prefix.length..]
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, body)

    Rack::Utils.secure_compare(expected, provided)
  end

  # Returns true if the given IP has exceeded the per-IP rate limit.
  # Limit: BULK_UPLOAD_RATE_LIMIT requests per BULK_UPLOAD_RATE_WINDOW seconds.
  def self.over_rate_limit?(redis, ip)
    max    = (ENV["BULK_UPLOAD_RATE_LIMIT"]  || "5").to_i
    window = (ENV["BULK_UPLOAD_RATE_WINDOW"] || "60").to_i
    key    = "#{RATE_LIMIT_KEY}:#{ip}"

    count = redis.incr(key)
    redis.expire(key, window) if count == 1

    count > max
  end

  # Returns true if the global in-flight job count is at or over the cap.
  # Cap: BULK_UPLOAD_MAX_INFLIGHT concurrent jobs.
  def self.over_inflight_limit?(redis)
    max = (ENV["BULK_UPLOAD_MAX_INFLIGHT"] || "10").to_i
    redis.get(INFLIGHT_KEY).to_i >= max
  end

  # Called in the endpoint after a job is enqueued.
  def self.increment_inflight!(redis)
    redis.incr(INFLIGHT_KEY)
  end

  # Called in the job's ensure block. Uses Sidekiq's connection pool —
  # no separate Redis client needed in the worker process.
  def self.decrement_inflight!
    Sidekiq.redis { |conn| conn.call("DECR", INFLIGHT_KEY) }
  end
end
