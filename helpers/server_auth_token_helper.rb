require 'digest'
require 'securerandom'

module ServerAuthTokenHelper
  # Wire name for direct-upload clients; Rack exposes it in the request env as
  # RACK_HEADER.
  HEADER = 'X-TreeStats-Server-Token'
  RACK_HEADER = "HTTP_#{HEADER.upcase.tr('-', '_')}"
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

  def self.apply_rate_limit_headers(headers, rate)
    remaining = [RATE_LIMIT_MAX - rate[:count], 0].max
    headers['RateLimit-Limit'] = RATE_LIMIT_MAX.to_s
    headers['RateLimit-Remaining'] = remaining.to_s
    # RateLimit-Reset is delta seconds; X-RateLimit-Reset is an epoch timestamp.
    headers['RateLimit-Reset'] = rate[:reset_in].to_s
    headers['X-RateLimit-Limit'] = RATE_LIMIT_MAX.to_s
    headers['X-RateLimit-Remaining'] = remaining.to_s
    headers['X-RateLimit-Reset'] = (Time.now.to_i + rate[:reset_in]).to_s
  end
end
