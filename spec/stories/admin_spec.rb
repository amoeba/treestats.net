require_relative '../story_helper.rb'

describe "AdminStory" do
  before do
    AdminUser.all.destroy
    ServerAuthToken.all.destroy
    DataPollState.collection.delete_many
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
      assert_includes last_response.body, 'no-referrer'
      assert_includes last_response.headers['Cache-Control'], 'no-store'
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

  describe "server upload tokens" do
    it "allows an admin to generate a server token" do
      server = ServerHelper.servers.first
      sign_in_admin

      get '/admin'
      post '/admin/upload-tokens', server: server, authenticity_token: extract_csrf

      assert_equal 302, last_response.status
      assert_equal '/admin/token', URI(last_response.location).path

      follow_redirect!

      assert_equal 200, last_response.status
      issued_token = last_response.body[/<pre>([^<]+)<\/pre>/, 1]&.strip
      refute_nil issued_token
      assert_match(/\Ats_/, issued_token)
      assert_includes last_response.body, "Token for #{server}"
      assert_includes last_response.body, 'X-TreeStats-Server-Token'
      assert_includes last_response.headers['Cache-Control'], 'no-store'

      record = ServerAuthToken.find_by(server: server)
      refute_equal issued_token, record.token_digest
      assert_equal ServerAuthTokenHelper.digest(issued_token), record.token_digest

      get '/admin'
      assert_includes last_response.body, record.updated_at.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
      assert_includes last_response.body, 'admin-utc-time'
      assert_includes last_response.headers['Cache-Control'], 'no-store'
    end

    it "shows the issued token exactly once" do
      server = ServerHelper.servers.first
      sign_in_admin

      issued_token = issue_token(server)
      refute_nil issued_token
      assert_equal 1, ServerAuthToken.where(server: server).count

      get '/admin/token'

      assert_equal 302, last_response.status
      assert_equal '/admin', URI(last_response.location).path
      assert_equal 1, ServerAuthToken.where(server: server).count
      refute_nil ServerAuthTokenHelper.authenticate(server, issued_token)
    end

    it "hides the issued token page from anonymous visitors" do
      get '/admin/token'

      assert_equal 404, last_response.status
    end

    it "creates unique indexes for server tokens" do
      sign_in_admin
      get '/admin'
      post '/admin/upload-tokens', server: ServerHelper.servers.first, authenticity_token: extract_csrf

      indexes = ServerAuthToken.collection.indexes.to_a
      server_index = indexes.find { |index| index['name'] == 'unique_server_auth_token_server' }
      digest_index = indexes.find { |index| index['name'] == 'unique_server_auth_token_digest' }

      assert server_index && server_index['unique'], 'expected a unique index on server'
      assert digest_index && digest_index['unique'], 'expected a unique index on token_digest'
    end

    it "reissues a token in place, invalidating the previous one" do
      server = ServerHelper.servers.first
      sign_in_admin

      first_token = issue_token(server)
      second_token = issue_token(server)

      refute_nil first_token
      refute_nil second_token
      refute_equal first_token, second_token
      assert_equal 1, ServerAuthToken.where(server: server).count
      assert_nil ServerAuthTokenHelper.authenticate(server, first_token), 'old token should be invalid'
      refute_nil ServerAuthTokenHelper.authenticate(server, second_token)
    end

    it "requires an authenticated admin and CSRF token" do
      post '/admin/upload-tokens', server: 'Test Server'
      assert_equal 404, last_response.status

      sign_in_admin
      post '/admin/upload-tokens', server: 'Test Server', authenticity_token: 'wrong'
      assert_equal 403, last_response.status
    end

    it "rejects an unregistered server" do
      sign_in_admin

      get '/admin'
      post '/admin/upload-tokens', server: 'Unregistered Server', authenticity_token: extract_csrf

      assert_equal 422, last_response.status
      assert_nil ServerAuthToken.where(server: 'Unregistered Server').first
    end

    it "revokes a token" do
      token = ServerAuthToken.create!(
        server: ServerHelper.servers.first,
        token_digest: ServerAuthTokenHelper.digest('test-token')
      )
      sign_in_admin

      get '/admin'
      post "/admin/upload-tokens/#{token.id}/revoke", authenticity_token: extract_csrf

      assert_equal 302, last_response.status
      assert_nil ServerAuthToken.where(id: token.id).first
    end
  end

  describe "GET /admin" do
    it "returns 404 for unknown admin paths" do
      sign_in_admin

      get '/admin/nope'

      assert_equal 404, last_response.status
    end

    it "does not let caches store the dashboard" do
      sign_in_admin

      get '/admin'

      assert_equal 200, last_response.status
      assert_includes last_response.headers['Cache-Control'], 'no-store'
    end

    it "shows configured poll target status" do
      DataPollState.create!(
        server: 'Hollowtide PK',
        last_checked_at: Time.utc(2026, 11, 7, 23, 0),
        last_outcome: 'failure',
        consecutive_failures: 2,
        error_summary: 'HTTP status 500'
      )
      original_targets = DataPoller.method(:targets)
      DataPoller.define_singleton_method(:targets) { {'Hollowtide PK' => 'https://hollowtide.org/population.json'} }
      sign_in_admin

      get '/admin'

      assert_equal 200, last_response.status
      assert_includes last_response.body, '<body class="admin-panel-page">'
      refute_includes last_response.body, 'TreeStats Network'
      assert_includes last_response.body, 'Hollowtide PK'
      assert_includes last_response.body, 'failure'
      assert_includes last_response.body, 'HTTP status 500'
    ensure
      DataPoller.define_singleton_method(:targets, original_targets) if original_targets
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

  def issue_token(server)
    get '/admin'
    post '/admin/upload-tokens', server: server, authenticity_token: extract_csrf
    follow_redirect!
    last_response.body[/<pre>([^<]+)<\/pre>/, 1]&.strip
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
