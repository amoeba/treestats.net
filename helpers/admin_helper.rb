require 'securerandom'

module AdminHelper
  LOGIN_MIN_FILL_SECONDS = 1.5
  LOGIN_RATE_LIMIT_WINDOW = 3600
  LOGIN_RATE_LIMIT_MAX = 8

  def admin?
    !!session[:admin_user_id]
  end

  def current_admin
    return nil unless admin?
    @current_admin ||= AdminUser.where(id: session[:admin_user_id]).first
  end

  def require_admin!
    halt 404 unless admin?
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
    count = redis.incr(key)
    redis.expire(key, LOGIN_RATE_LIMIT_WINDOW) if count == 1
  end
end
