require "digest"

# Fixed-window counter shared by admin login throttling and server upload
# tokens. Kept in one place so the Lua semantics cannot drift between callers.
module RateLimiter
  LUA = <<~LUA
    local count = redis.call('INCR', KEYS[1])
    if count == 1 then
      redis.call('EXPIRE', KEYS[1], tonumber(ARGV[1]))
    end
    return {count, redis.call('TTL', KEYS[1])}
  LUA
  LUA_SHA = Digest::SHA1.hexdigest(LUA)

  # Increments +key+ and returns {count:, reset_in:}. +reset_in+ is seconds
  # until the window closes.
  def self.record!(redis, key, window)
    count, ttl = begin
      redis.evalsha(LUA_SHA, keys: [key], argv: [window])
    rescue Redis::CommandError => e
      raise unless e.message.include?("NOSCRIPT")

      redis.eval(LUA, keys: [key], argv: [window])
    end

    {count: count.to_i, reset_in: [ttl.to_i, 0].max}
  end

  def self.preload!(redis)
    redis.script(:load, LUA)
  rescue => e
    warn "Rate-limit Lua pre-load failed: #{e.message}"
  end
end
