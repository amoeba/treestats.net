require 'securerandom'
require 'digest'

module AdminHelper
  LOGIN_MIN_FILL_SECONDS = 1.5
  LOGIN_RATE_LIMIT_WINDOW = 3600
  LOGIN_RATE_LIMIT_MAX = 8

  RATE_LIMIT_LUA = <<~LUA
    local count = redis.call('INCR', KEYS[1])
    if count == 1 then
      redis.call('EXPIRE', KEYS[1], tonumber(ARGV[1]))
    end
    return count
  LUA
  RATE_LIMIT_LUA_SHA = Digest::SHA1.hexdigest(RATE_LIMIT_LUA)

  def admin?
    !!session[:admin_user_id]
  end

  def current_admin
    return nil unless admin?
    @current_admin ||= AdminUser.where(id: session[:admin_user_id]).first
  end

  def require_admin!
    halt 404 unless admin?
    # Admin responses can contain bearer tokens (e.g. a freshly issued upload
    # token), so they must never be stored by a browser or intermediary cache.
    headers['Cache-Control'] = 'no-store, private'
  end

  def csrf_token
    session[:csrf] ||= SecureRandom.hex(32)
  end

  def verify_csrf!
    submitted = params['authenticity_token'].to_s
    expected = session[:csrf].to_s
    if expected.empty? || submitted.empty? || !Rack::Utils.secure_compare(expected, submitted)
      halt 403, 'Invalid request.'
    end
  end

  def admin_login_rate_limit_key
    "admin:login:attempts:#{request.ip}"
  end

  def admin_login_rate_limited?
    count = redis.get(admin_login_rate_limit_key).to_i
    count >= LOGIN_RATE_LIMIT_MAX
  end

  def record_failed_login_attempt!
    key = admin_login_rate_limit_key
    begin
      redis.evalsha(RATE_LIMIT_LUA_SHA, keys: [key], argv: [LOGIN_RATE_LIMIT_WINDOW])
    rescue Redis::CommandError => e
      raise unless e.message.include?('NOSCRIPT')
      redis.eval(RATE_LIMIT_LUA, keys: [key], argv: [LOGIN_RATE_LIMIT_WINDOW])
    end
  end

  def render_admin_dashboard
    states = DataPollState.in(server: DataPoller.targets.keys).to_a.each_with_object({}) do |state, result|
      result[state.server] = state
    end
    @poll_interval = DataPoller.config.fetch("interval", DataPoller::DEFAULT_INTERVAL)
    @poll_targets = DataPoller.targets.map do |server, url|
      {server: server, url: url, state: states[server]}
    end
    @tokens = ServerAuthToken.asc(:server).to_a
    @registered_servers = ServerHelper.servers.sort
    haml :admin, layout: false
  end

  def generate_upload_token
    server = params['server'].to_s.strip
    halt 400, 'Server name is required.' if server.empty?
    halt 422, 'Server must be registered.' unless ServerHelper.servers.include?(server)

    token = ServerAuthTokenHelper.generate
    ServerAuthToken.issue!(server, ServerAuthTokenHelper.digest(token))

    # Show the plaintext token once, on its own page. Keeping it in the signed
    # session for a single redirect avoids re-issuing on a page reload.
    session[:issued_token] = {'server' => server, 'token' => token}
    redirect '/admin/token'
  end
end
