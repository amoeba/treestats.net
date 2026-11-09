require_relative '../story_helper.rb'

describe "UploadTokenStory" do
  before do
    ServerAuthToken.all.destroy
    # Upload callbacks create patron/monarch characters, so clear whole servers.
    Character.unscoped.in(server: ['Token Server', 'Other Server', 'Example Server']).destroy
    PlayerCount.in(server: ['Token Server', 'Other Server', 'Example Server']).destroy
    Allegiance.in(server: ['Token Server', 'Other Server', 'Example Server']).destroy
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

  it "accepts a matching server token without calling the plugin body verifier" do
    token = create_server_token('Token Server')

    with_env('TREESTATS_SECRET' => 'x == "plugin"') do
      post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token
    end

    assert_equal 200, last_response.status
    assert_equal '1000', last_response.headers['RateLimit-Limit']
    assert_equal '999', last_response.headers['RateLimit-Remaining']
    assert last_response.headers['RateLimit-Reset'].to_i.between?(1, 3600)
  end

  it "rejects account_name on direct uploads regardless of its value without writing data" do
    token = create_server_token('Token Server')

    ['claimed-account', '', nil, 123, {}].each do |account_name|
      payload = JSON.parse(upload_body('Token Server')).merge(
        'account_name' => account_name,
        'server_population' => 123,
        'monarch' => {'name' => 'Monarch'},
        'allegiance_name' => 'Allegiance'
      )

      post '/characters', JSON.generate(payload), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

      assert_equal 400, last_response.status
      assert_includes last_response.body, 'account_name is only allowed for plugin uploads to POST /'
      assert_equal 0, Character.unscoped.where(server: 'Token Server').count
      assert_equal 0, PlayerCount.where(server: 'Token Server').count
      assert_equal 0, Allegiance.where(server: 'Token Server').count
    end
  end

  it "rejects account fields on related characters and the stored-field alias" do
    token = create_server_token('Token Server')
    [
      {'acc' => 'claimed-account'},
      {'monarch' => {'name' => 'Monarch', 'account_name' => 'claimed-account'}},
      {'patron' => {'name' => 'Patron', 'acc' => nil}},
      {'vassals' => [{'name' => 'Vassal', 'account_name' => ''}]}
    ].each do |fields|
      payload = JSON.parse(upload_body('Token Server')).merge(fields)

      post '/characters/', JSON.generate(payload), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

      assert_equal 400, last_response.status
      assert_includes last_response.body, 'only allowed for plugin uploads'
      assert_equal 0, Character.unscoped.where(server: 'Token Server').count
    end
  end

  it "preserves a plugin account on valid direct uploads and rejected account changes" do
    token = create_server_token('Token Server')
    payload = JSON.parse(upload_body('Token Server')).merge('account_name' => 'plugin-account', 'level' => 10)

    without_env('TREESTATS_SECRET') do
      post '/', JSON.generate(payload)
    end
    assert_equal 200, last_response.status
    character = Character.unscoped.find_by(server: 'Token Server', name: 'Token User')
    assert_equal 'plugin-account', character.account_name

    [nil, '', 'other-account'].each do |account_name|
      post '/characters', JSON.generate(payload.merge('account_name' => account_name, 'level' => 20)),
        'HTTP_X_TREESTATS_SERVER_TOKEN' => token

      assert_equal 400, last_response.status
      character.reload
      assert_equal 'plugin-account', character.account_name
      assert_equal 10, character.level
      refute character.uploaded_by_server?
    end

    post '/characters', JSON.generate(payload.reject { |key, _| key == 'account_name' }.merge('level' => 30)),
      'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    character.reload
    assert_equal 'plugin-account', character.account_name
    assert_equal 30, character.level
    assert character.uploaded_by_server?
  end

  it "rejects a token issued for another server without writing anything" do
    token = create_server_token('Token Server')

    post '/characters', upload_body('Other Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 403, last_response.status
    assert_nil Character.unscoped.where(server: 'Other Server', name: 'Token User').first
    assert_equal 0, PlayerCount.where(server: 'Other Server').count
  end

  it "rejects a revoked token" do
    token = create_server_token('Token Server')
    ServerAuthToken.find_by(server: 'Token Server').destroy

    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 403, last_response.status
    assert_nil Character.unscoped.where(server: 'Token Server', name: 'Token User').first
  end

  it "falls back to EVAL when the rate-limit script is not cached" do
    token = create_server_token('Token Server')
    redis.script(:flush)

    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    assert last_response.headers['RateLimit-Remaining'].to_i.between?(0, 999)
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

  it "uses the plugin body verifier when no server token header is sent" do
    with_env('TREESTATS_SECRET' => 'x == "plugin"') do
      post '/', 'other'
    end

    assert_equal 403, last_response.status
  end

  it "accepts a plugin upload at the root endpoint" do
    without_env('TREESTATS_SECRET') do
      post '/', upload_body('Token Server')
    end

    assert_equal 200, last_response.status
  end

  it "samples successful plugin uploads before normalization, but not direct uploads" do
    token = create_server_token('Token Server')
    payload = {name: 'Token User', server: 'Token Server', level: '50', birth: '1/15/2000 8:30:00 PM'}
    body = JSON.pretty_generate(payload)
    sampled = []
    captured = []

    original_sample = UploadSampling.method(:sample)
    original_capture = UploadSampling.method(:capture)
    UploadSampling.define_singleton_method(:sample) { |text| sampled << text; :sample }
    UploadSampling.define_singleton_method(:capture) { |sample| captured << sample }
    begin
      with_env('RACK_ENV' => 'production') do
        without_env('TREESTATS_SECRET') { post '/', body }
        assert_equal 200, last_response.status
        post '/characters', JSON.generate(payload), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token
        assert_equal 200, last_response.status
      end
    ensure
      UploadSampling.define_singleton_method(:sample, original_sample)
      UploadSampling.define_singleton_method(:capture, original_capture)
    end

    assert_equal [body], sampled
    assert_equal [:sample], captured
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

  it "rejects valid JSON that is not an object on the plugin endpoint" do
    without_env('TREESTATS_SECRET') do
      ['null', '[]', '5'].each do |body|
        post '/', body

        assert_equal 400, last_response.status, "expected 400 for #{body}"
        assert_includes last_response.body, 'JSON object'
      end
    end
  end

  it "accepts the minimal and maximal examples from the docs" do
    token = create_server_token('Example Server')
    docs = File.read(File.expand_path('../../docs/direct-upload.md', __dir__))

    allowed = Character::UPLOAD_FIELDS + %w[server_population]

    %w[minimal maximal].each do |name|
      body = docs[/<!-- example:#{name} -->\s*```json\n(.*?)```/m, 1]
      refute_nil body, "docs are missing the #{name} example"

      payload = JSON.parse(body)
      assert_empty payload.keys - allowed, "#{name} example contains fields the uploader ignores"
      refute payload.key?('account_name'), "#{name} direct upload example contains a plugin-only field"

      post '/characters', body, 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

      assert_equal 200, last_response.status, "#{name} example was rejected: #{last_response.body}"
    end

    character = Character.unscoped.find_by(server: 'Example Server', name: 'Maximal Example')
    assert_equal 275, character.level
    refute_nil character.birth
    assert_equal 'Example Patron', character.patron['name']
    assert_equal ['Example Vassal'], character.vassals.map { |vassal| vassal['name'] }
    assert_equal 123, PlayerCount.find_by(server: 'Example Server').count
  end

  it "ignores unknown fields without failing" do
    token = create_server_token('Token Server')
    payload = JSON.parse(upload_body('Token Server')).merge('_id' => '0' * 24, 'plugin_version' => '3')

    post '/characters', JSON.generate(payload), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    character = Character.unscoped.where(server: 'Token Server', name: 'Token User').first
    refute_nil character
    refute_equal '0' * 24, character.id.to_s
  end

  it "ignores an ip_address supplied in a direct upload" do
    token = create_server_token('Token Server')
    payload = JSON.parse(upload_body('Token Server')).merge('ip_address' => '9.9.9.9')

    post '/characters', JSON.generate(payload), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    assert_nil Character.unscoped.find_by(server: 'Token Server', name: 'Token User').ip
  end

  it "rejects a non-string server instead of treating it as a query" do
    token = create_server_token('Token Server')
    victim = Character.unscoped.create!(name: 'Token User', server: 'Other Server', level: 7)

    post '/characters', JSON.generate('server' => {'$ne' => nil}, 'name' => 'Token User', 'level' => 50),
      'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 400, last_response.status
    victim.reload
    assert_equal 7, victim.level
    assert_equal 'Other Server', victim.server
  end

  it "rejects a non-string name instead of treating it as a query" do
    token = create_server_token('Token Server')

    post '/characters', JSON.generate('server' => 'Token Server', 'name' => {'$ne' => nil}, 'level' => 50),
      'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 400, last_response.status
  end

  it "ignores an invalid server_population and still saves the character" do
    token = create_server_token('Token Server')

    post '/characters', JSON.generate(server: 'Token Server', name: 'Token User', server_population: -5),
      'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    assert_equal 0, PlayerCount.where(server: 'Token Server').count
    refute_nil Character.unscoped.where(server: 'Token Server', name: 'Token User').first
  end

  it "drops malformed vassal entries instead of crashing" do
    token = create_server_token('Token Server')
    payload = JSON.parse(upload_body('Token Server')).merge('vassals' => ['x', {'name' => 'Real Vassal'}])

    post '/characters', JSON.generate(payload), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    character = Character.unscoped.find_by(server: 'Token Server', name: 'Token User')
    assert_equal ['Real Vassal'], character.vassals.map { |vassal| vassal['name'] }
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

  it "records direct uploads as server-sourced" do
    token = create_server_token('Token Server')

    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token

    assert_equal 200, last_response.status
    character = Character.unscoped.find_by(server: 'Token Server', name: 'Token User')
    assert_equal Character::SERVER_SOURCE, character.upload_source
    assert character.uploaded_by_server?
  end

  it "clears server provenance when the plugin uploads next" do
    token = create_server_token('Token Server')
    post '/characters', upload_body('Token Server'), 'HTTP_X_TREESTATS_SERVER_TOKEN' => token
    assert_equal Character::SERVER_SOURCE, Character.unscoped.find_by(server: 'Token Server', name: 'Token User').upload_source

    without_env('TREESTATS_SECRET') do
      post '/', upload_body('Token Server')
    end

    assert_equal 200, last_response.status
    character = Character.unscoped.find_by(server: 'Token Server', name: 'Token User')
    assert_nil character.upload_source
    refute character.uploaded_by_server?
  end

  it "rejects an oversized direct upload before reading it" do
    oversized = 'x' * (UploadHelper::MAX_UPLOAD_BYTES + 1)

    post '/characters', oversized, 'HTTP_X_TREESTATS_SERVER_TOKEN' => 'ts_whatever'

    assert_equal 413, last_response.status
  end

  it "rejects an oversized plugin-endpoint upload before reading it" do
    oversized = 'x' * (UploadHelper::MAX_UPLOAD_BYTES + 1)

    without_env('TREESTATS_SECRET') do
      post '/', oversized
    end

    assert_equal 413, last_response.status
  end
end
