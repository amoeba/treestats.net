require "redis"

class RateLimiter
  def initialize(app, options = {})
    @app = app
    @limit = options[:limit] || 100
    @seconds = options[:seconds] || 60
    @redis = Redis.new
  end

  def call(env)
    ip = env['REMOTE_ADDR']
    key = build_key(ip)

    count = increment(key)

    if count > @limit
      [429, { 'Content-Type' => 'text/plain' }, ['Rate limit exceeded']]
    else
      @app.call(env)
    end
  end

  private

  def build_key(ip)
    "rate_limiter:#{ip}:#{Time.now.to_i / @seconds}"
  end

  def increment(key)
    count = @redis.incr(key)

    @redis.expire(key, @seconds) if count == 1

    count
  end
end
