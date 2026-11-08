require_relative '../story_helper.rb'

describe "UploadTokenStory" do
  before do
    ServerAuthToken.all.destroy
    # Upload callbacks create patron/monarch characters, so clear the whole server.
    Character.unscoped.where(server: 'Token Server').destroy
    PlayerCount.where(server: 'Token Server').destroy
    redis.keys('uploads:server-token:*').each { |key| redis.del(key) }
  end

  def create_server_token(server)
    token = ServerAuthTokenHelper.generate
    ServerAuthToken.create!(server: server, token_digest: ServerAuthTokenHelper.digest(token))
    token
  end

  def upload_body(server)
    JSON.generate(
      name: 'Token User',
      server: server,
      patron: {'name' => 'Patron', 'race' => 1, 'gender' => 1, 'rank' => 1}
    )
  end

  it "accepts a matching server token without calling the legacy validator" do
    token = create_server_token('Token Server')

    with_env('TREESTATS_SECRET' => 'x == "legacy"') do
      post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token
    end

    assert_equal 200, last_response.status
    assert_equal '1000', last_response.headers['RateLimit-Limit']
    assert_equal '999', last_response.headers['RateLimit-Remaining']
    assert last_response.headers['RateLimit-Reset'].to_i.between?(1, 3600)
  end

  it "rejects a token issued for another server" do
    token = create_server_token('Token Server')

    post '/characters', upload_body('Other Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 403, last_response.status
  end

  it "returns 429 after 1,000 token-authenticated uploads in an hour" do
    token = create_server_token('Token Server')
    redis.set(
      "uploads:server-token:#{ServerAuthTokenHelper.digest(token)}",
      ServerAuthTokenHelper::RATE_LIMIT_MAX,
      ex: ServerAuthTokenHelper::RATE_LIMIT_WINDOW
    )

    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 429, last_response.status
    assert_equal '0', last_response.headers['RateLimit-Remaining']
    assert last_response.headers['RateLimit-Reset'].to_i.between?(1, 3600)
  end

  it "uses the legacy validator when no server token header is sent" do
    with_env('TREESTATS_SECRET' => 'x == "legacy"') do
      post '/', 'other'
    end

    assert_equal 403, last_response.status
  end

  it "accepts a legacy plugin upload at the root endpoint" do
    without_env('TREESTATS_SECRET') do
      post '/', upload_body('Token Server')
    end

    assert_equal 200, last_response.status
  end

  it "requires a server token on the direct upload endpoint" do
    post '/characters', upload_body('Token Server')

    assert_equal 401, last_response.status
  end

  it "rejects valid JSON that is not an object" do
    token = create_server_token('Token Server')

    ['null', '[]', '"string"', '5', 'true'].each do |body|
      post '/characters', body, 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

      assert_equal 400, last_response.status, "expected 400 for #{body}"
      assert_includes last_response.body, 'JSON object'
    end

    assert_equal 0, Character.unscoped.where(server: 'Token Server').count
    assert_equal 0, PlayerCount.where(server: 'Token Server').count
  end

  it "rejects valid JSON that is not an object on the legacy endpoint" do
    without_env('TREESTATS_SECRET') do
      ['null', '[]', '5'].each do |body|
        post '/', body

        assert_equal 400, last_response.status, "expected 400 for #{body}"
        assert_includes last_response.body, 'JSON object'
      end
    end
  end

  it "does not record the caller address as the character's IP on direct uploads" do
    token = create_server_token('Token Server')

    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    character = Character.unscoped.find_by(server: 'Token Server', name: 'Token User')
    refute_nil character
    assert_nil character.ip
  end

  it "does not overwrite an IP recorded by the plugin on direct uploads" do
    token = create_server_token('Token Server')
    Character.unscoped.create!(name: 'Token User', server: 'Token Server', ip: '10.0.0.1')

    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    assert_equal '10.0.0.1', Character.unscoped.find_by(server: 'Token Server', name: 'Token User').ip
  end

  it "records the caller address for plugin uploads" do
    without_env('TREESTATS_SECRET') do
      post '/', upload_body('Token Server')
    end

    assert_equal 200, last_response.status
    assert_equal '127.0.0.1', Character.unscoped.find_by(server: 'Token Server', name: 'Token User').ip
  end

  it "rejects an oversized direct upload before reading it" do
    oversized = 'x' * (UploadHelper::MAX_UPLOAD_BYTES + 1)

    post '/characters', oversized, 'HTTP_X_TREESTATS_SERVER_TOKEN' => 'ts_whatever'

    assert_equal 413, last_response.status
  end

  it "rejects an oversized legacy upload before reading it" do
    oversized = 'x' * (UploadHelper::MAX_UPLOAD_BYTES + 1)

    without_env('TREESTATS_SECRET') do
      post '/', oversized
    end

    assert_equal 413, last_response.status
  end
end
