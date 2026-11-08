require 'digest'
require 'securerandom'

module ServerAuthTokenHelper
  HEADER = 'HTTP_X_TREESTATS_SERVER_TOKEN'
  TOKEN_PREFIX = 'ts_'
  RATE_LIMIT_WINDOW = 3600
  RATE_LIMIT_MAX = 1000

  RATE_LIMIT_LUA = <<~LUA
    local count = redis.call('INCR', KEYS[1])
    if count == 1 then
      redis.call('EXPIRE', KEYS[1], tonumber(ARGV[1]))
    end
    return {count, redis.call('TTL', KEYS[1])}
  LUA
  RATE_LIMIT_LUA_SHA = Digest::SHA1.hexdigest(RATE_LIMIT_LUA)

  def self.generate
    "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32, false)}"
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.authenticate(server, token)
    return nil if server.to_s.empty? || token.to_s.empty?

    record = ServerAuthToken.where(server: server).first
    return nil unless record
    return nil unless Rack::Utils.secure_compare(record.token_digest, digest(token))

    record
  end

  def self.record_request!(redis, token)
    key = "uploads:server-token:#{digest(token)}"
    count, ttl = begin
      redis.evalsha(RATE_LIMIT_LUA_SHA, keys: [key], argv: [RATE_LIMIT_WINDOW])
    rescue Redis::CommandError => e
      raise unless e.message.include?('NOSCRIPT')

      redis.eval(RATE_LIMIT_LUA, keys: [key], argv: [RATE_LIMIT_WINDOW])
    end

    {count: count.to_i, reset_in: [ttl.to_i, 0].max}
  end

  def self.apply_rate_limit_headers(headers, limit)
    remaining = [RATE_LIMIT_MAX - limit[:count], 0].max
    headers['RateLimit-Limit'] = RATE_LIMIT_MAX.to_s
    headers['RateLimit-Remaining'] = remaining.to_s
    headers['RateLimit-Reset'] = limit[:reset_in].to_s
    headers['X-RateLimit-Limit'] = RATE_LIMIT_MAX.to_s
    headers['X-RateLimit-Remaining'] = remaining.to_s
    headers['X-RateLimit-Reset'] = (Time.now.to_i + limit[:reset_in]).to_s
  end
end
