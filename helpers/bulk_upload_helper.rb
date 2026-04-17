require "openssl"

module BulkUploadHelper
  SIGNATURE_HEADER = "HTTP_X_TREESTATS_UPLOAD_SIGNATURE"
  API_KEY_HEADER   = "HTTP_X_TREESTATS_API_KEY"
  TOKEN_PREFIX     = "ts_"
  ACCOUNT_ID_LEN   = 24 # MongoDB ObjectId as hex
  INFLIGHT_KEY     = "bulk_upload:inflight"
  RATE_LIMIT_KEY   = "bulk_upload:ratelimit"

  def self.account_id_from_request(request)
    token = request.env[API_KEY_HEADER].to_s
    token.start_with?(TOKEN_PREFIX) ? token[TOKEN_PREFIX.length, ACCOUNT_ID_LEN] : nil
  end

  def self.valid_signature?(request, body)
    token = request.env[API_KEY_HEADER]
    return false if token.nil? || !token.start_with?(TOKEN_PREFIX)

    account_id_str = token[TOKEN_PREFIX.length, ACCOUNT_ID_LEN]
    return false if account_id_str.nil? || account_id_str.length != ACCOUNT_ID_LEN

    api_key = ApiKey.where(account_id: account_id_str).first
    return false if api_key.nil?

    header = request.env[SIGNATURE_HEADER]
    return false if header.nil?

    sig_prefix = "sha256="
    return false unless header.start_with?(sig_prefix)

    provided = header[sig_prefix.length..]
    expected = OpenSSL::HMAC.hexdigest("SHA256", api_key.secret, body)

    Rack::Utils.secure_compare(expected, provided)
  end

  # Returns true if the given IP has exceeded the per-IP rate limit.
  # Limit: BULK_UPLOAD_RATE_LIMIT requests per BULK_UPLOAD_RATE_WINDOW seconds.
  def self.over_rate_limit?(redis, ip)
    max    = (ENV["BULK_UPLOAD_RATE_LIMIT"]  || "5").to_i
    window = (ENV["BULK_UPLOAD_RATE_WINDOW"] || "60").to_i
    key    = "#{RATE_LIMIT_KEY}:#{ip}"

    count = redis.eval(
      "local n = redis.call('INCR', KEYS[1]); if n == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end; return n",
      keys: [key], argv: [window]
    )

    count > max
  end

  # Atomically increments the in-flight counter only if below cap.
  # Returns true if the slot was acquired, false if the cap was already reached.
  # Uses a Lua script to ensure the check-and-increment is atomic.
  # Cap: BULK_UPLOAD_MAX_INFLIGHT concurrent jobs.
  def self.try_increment_inflight!(redis)
    max = (ENV["BULK_UPLOAD_MAX_INFLIGHT"] || "10").to_i
    # Returns 1 if incremented (slot acquired), 0 if cap already reached.
    result = redis.eval(
      "local n = redis.call('GET', KEYS[1]); n = tonumber(n) or 0; if n < tonumber(ARGV[1]) then redis.call('INCR', KEYS[1]); return 1 else return 0 end",
      keys: [INFLIGHT_KEY], argv: [max]
    )
    result == 1
  end

  # Called in the job's ensure block. Accepts an explicit redis client for
  # testing; defaults to Sidekiq's connection pool in production.
  def self.decrement_inflight!(redis = nil)
    if redis
      redis.decr(INFLIGHT_KEY)
    else
      Sidekiq.redis { |conn| conn.call("DECR", INFLIGHT_KEY) }
    end
  end
end
