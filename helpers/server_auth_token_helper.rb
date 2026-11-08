require 'digest'
require 'securerandom'

module ServerAuthTokenHelper
  HEADER = 'HTTP_X_TREESTATS_SERVER_TOKEN'
  TOKEN_PREFIX = 'ts_'
  RATE_LIMIT_WINDOW = 3600
  RATE_LIMIT_MAX = 1000

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
    RateLimiter.record!(redis, "uploads:server-token:#{digest(token)}", RATE_LIMIT_WINDOW)
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
