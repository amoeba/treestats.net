require_relative '../story_helper.rb'

describe "AdminStory" do
  before do
    AdminUser.all.destroy
    Character.all.destroy
    Character.unscoped.where(server: 'test', name: 'archived_char').destroy
    redis.del("admin:login:attempts:127.0.0.1")
  end

  def create_admin(name: 'admin', password: 'correct-horse-battery')
    user = AdminUser.new(name: name)
    user.password = password
    user.save!
    user
  end

  describe "GET /admin/login" do
    it "renders the login form" do
      get '/admin/login'
      assert_equal 200, last_response.status
      assert_includes last_response.body, 'name="name"'
      assert_includes last_response.body, 'name="password"'
      assert_includes last_response.body, 'name="authenticity_token"'
      assert_includes last_response.body, 'noindex'
    end

    it "is hidden when already logged in" do
      create_admin
      get '/admin/login'
      assert_equal 200, last_response.status

      token = extract_csrf
      with_time_advanced(2) do
        post '/admin/login', authenticity_token: token, name: 'admin', password: 'correct-horse-battery'
      end
      get '/admin/login'
      assert_equal 404, last_response.status
    end
  end

  describe "POST /admin/login" do
    it "rejects bad CSRF" do
      get '/admin/login'
      post '/admin/login', authenticity_token: 'wrong', name: 'admin', password: 'whatever'
      assert_equal 403, last_response.status
    end

    it "rejects honeypot submissions" do
      create_admin
      get '/admin/login'
      post '/admin/login',
           authenticity_token: extract_csrf,
           name: 'admin',
           password: 'correct-horse-battery',
           website: 'http://spam.example'
      assert_equal 404, last_response.status
    end

    it "rejects submissions faster than the time-trap" do
      create_admin
      get '/admin/login'
      token = extract_csrf
      post '/admin/login', authenticity_token: token, name: 'admin', password: 'correct-horse-battery'
      assert_equal 404, last_response.status
    end

    it "logs in with valid credentials after the time-trap" do
      create_admin
      get '/admin/login'
      token = extract_csrf
      with_time_advanced(2) do
        post '/admin/login', authenticity_token: token, name: 'admin', password: 'correct-horse-battery'
      end
      assert_equal 302, last_response.status
      assert_equal 'http://example.org/', last_response.headers['Location']
    end

    it "returns 404 (not 401) on bad credentials to avoid revealing endpoint" do
      create_admin
      get '/admin/login'
      token = extract_csrf
      with_time_advanced(2) do
        post '/admin/login', authenticity_token: token, name: 'admin', password: 'WRONG'
      end
      assert_equal 404, last_response.status
    end

    it "rate-limits repeated failures" do
      create_admin
      AdminHelper::LOGIN_RATE_LIMIT_MAX.times do
        get '/admin/login'
        post '/admin/login', authenticity_token: extract_csrf, name: 'admin', password: 'wrong', website: 'spam'
      end
      get '/admin/login'
      token = extract_csrf
      with_time_advanced(2) do
        post '/admin/login', authenticity_token: token, name: 'admin', password: 'correct-horse-battery'
      end
      assert_equal 404, last_response.status
    end
  end

  describe "Admin widget on character pages" do
    before do
      Character.create(name: 'admin_char', server: 'test')
    end

    it "is hidden for anonymous visitors" do
      get '/test/admin_char'
      assert_equal 200, last_response.status
      refute_includes last_response.body, 'admin-widget'
    end

    it "is shown for logged-in admin" do
      sign_in_admin

      get '/test/admin_char'
      assert_equal 200, last_response.status
      assert_includes last_response.body, 'admin-widget'
      assert_includes last_response.body, 'Archive'
    end
  end

  describe "POST /admin/character/:server/:name/archive" do
    before do
      Character.create(name: 'admin_char', server: 'test')
    end

    it "rejects unauthenticated requests" do
      post '/admin/character/test/admin_char/archive', archived: 'true'
      assert_equal 404, last_response.status
    end

    it "archives a character when admin is logged in" do
      sign_in_admin

      get '/test/admin_char'
      token = extract_widget_csrf

      post '/admin/character/test/admin_char/archive',
           archived: 'true',
           authenticity_token: token

      assert_equal 200, last_response.status
      character = Character.unscoped.find_by(server: 'test', name: 'admin_char')
      assert_equal true, character.archived
    end

    it "unarchives a character" do
      sign_in_admin

      Character.unscoped.find_by(server: 'test', name: 'admin_char').set(archived: true)

      get '/test/admin_char'
      token = extract_widget_csrf

      post '/admin/character/test/admin_char/archive',
           archived: 'false',
           authenticity_token: token

      assert_equal 200, last_response.status
      character = Character.unscoped.find_by(server: 'test', name: 'admin_char')
      assert_equal false, character.archived
    end
  end

  private

  def with_time_advanced(seconds)
    future = Time.now + seconds
    Time.singleton_class.alias_method :__real_now, :now
    Time.singleton_class.define_method(:now) { future }
    yield
  ensure
    if Time.singleton_class.method_defined?(:__real_now)
      Time.singleton_class.alias_method :now, :__real_now
      Time.singleton_class.remove_method :__real_now
    end
  end

  def extract_csrf
    last_response.body[/name="authenticity_token"[^>]*value="([^"]+)"/, 1] ||
      last_response.body[/value="([^"]+)"[^>]*name="authenticity_token"/, 1]
  end

  def extract_widget_csrf
    last_response.body[/authenticity_token&quot;:&quot;([a-f0-9]+)&quot;/, 1] || extract_csrf
  end

  def sign_in_admin
    create_admin
    get '/admin/login'
    token = extract_csrf
    with_time_advanced(2) do
      post '/admin/login', authenticity_token: token, name: 'admin', password: 'correct-horse-battery'
    end
  end
end
