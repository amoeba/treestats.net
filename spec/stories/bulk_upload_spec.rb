require_relative '../story_helper.rb'
require 'sidekiq/testing'
require 'openssl'

describe "BulkUploadStory" do
  let(:emu_server)    { "TestServer" }
  let(:retail_server) { AppHelper.retail_servers.first }

  def sign(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
  end

  # Post to POST /characters with the right headers.
  # Pass signature: nil to omit the signature header entirely.
  # Pass api_key: nil to omit the api key header entirely.
  def post_characters(body, content_type: "application/x-ndjson",
                      signature: sign(body, @api_key.secret),
                      api_key: @api_key.secret)
    env = { "CONTENT_TYPE" => content_type }
    env["HTTP_X_TREESTATS_UPLOAD_SIGNATURE"] = signature unless signature.nil?
    env["HTTP_X_TREESTATS_API_KEY"] = api_key unless api_key.nil?
    post("/characters", body, env)
  end

  before do
    redis.del(BulkUploadHelper::INFLIGHT_KEY)
    redis.del("#{BulkUploadHelper::RATE_LIMIT_KEY}:127.0.0.1")
    Character.all.destroy
    Allegiance.all.destroy
    BulkUploadLog.all.destroy
    ApiKey.all.destroy
    Account.all.destroy
    @account = Account.create!(name: "TestUser", password: "pass")
    @api_key = ApiKey.create!(account: @account)
    Sidekiq::Testing.fake! # default: enqueue without running
  end

  after do
    Sidekiq::Testing.fake!
  end

  # ---------------------------------------------------------------------------
  describe "signature verification" do
    it "returns 403 when the signature header is missing" do
      post_characters({ name: "Foo", server: emu_server }.to_json, signature: nil)
      assert_equal 403, last_response.status
    end

    it "returns 403 when the api key header is missing" do
      post_characters({ name: "Foo", server: emu_server }.to_json, api_key: nil)
      assert_equal 403, last_response.status
    end

    it "returns 403 when the signature is wrong" do
      post_characters({ name: "Foo", server: emu_server }.to_json, signature: "sha256=deadbeef")
      assert_equal 403, last_response.status
    end

    it "returns 403 with a JSON error body" do
      post_characters({ name: "Foo", server: emu_server }.to_json, signature: nil)
      body = JSON.parse(last_response.body)
      assert_equal "invalid signature", body["error"]
    end

    it "returns 202 with a valid signature" do
      post_characters({ name: "Foo", server: emu_server }.to_json)
      assert_equal 202, last_response.status
    end
  end

  # ---------------------------------------------------------------------------
  describe "rate limiting" do
    it "returns 202 when under the per-IP limit" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "5") do
        post_characters({ name: "Foo", server: emu_server }.to_json)
        assert_equal 202, last_response.status
      end
    end

    it "returns 429 once the per-IP limit is exceeded" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "2") do
        body = { name: "Foo", server: emu_server }.to_json
        2.times { post_characters(body) }
        post_characters(body)
        assert_equal 429, last_response.status
      end
    end

    it "returns a JSON error body on 429" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "0") do
        post_characters({ name: "Foo", server: emu_server }.to_json)
        body = JSON.parse(last_response.body)
        assert_equal "rate limit exceeded", body["error"]
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe "inflight limiting" do
    it "returns 202 when inflight is below the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        post_characters({ name: "Foo", server: emu_server }.to_json)
        assert_equal 202, last_response.status
      end
    end

    it "returns 503 when the inflight limit is reached" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "1") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 1)
        post_characters({ name: "Foo", server: emu_server }.to_json)
        assert_equal 503, last_response.status
      end
    end

    it "returns a JSON error body on 503" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "1") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 1)
        post_characters({ name: "Foo", server: emu_server }.to_json)
        body = JSON.parse(last_response.body)
        assert_equal "too many jobs in flight, try again later", body["error"]
      end
    end

    it "increments the inflight counter when a job is queued" do
      post_characters({ name: "Foo", server: emu_server }.to_json)
      assert_equal 1, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end
  end

  # ---------------------------------------------------------------------------
  describe "response format" do
    it "returns application/json content type on 202" do
      post_characters({ name: "Foo", server: emu_server }.to_json)
      assert last_response.headers["Content-Type"].include?("application/json")
    end

    it "returns a JSON body with status queued on 202" do
      post_characters({ name: "Foo", server: emu_server }.to_json)
      body = JSON.parse(last_response.body)
      assert_equal "queued", body["status"]
    end

    it "returns application/json content type on 403" do
      post_characters({ name: "Foo", server: emu_server }.to_json, signature: nil)
      assert last_response.headers["Content-Type"].include?("application/json")
    end
  end

  # ---------------------------------------------------------------------------
  describe "end-to-end with inline job execution" do
    before { Sidekiq::Testing.inline! }

    it "creates characters from NDJSON" do
      body = [
        { "name" => "Stormwall", "server" => emu_server },
        { "name" => "Asheron",   "server" => emu_server }
      ].map(&:to_json).join("\n")

      post_characters(body)

      assert_equal 202, last_response.status
      assert_equal 2, Character.count
      assert Character.find_by(name: "Stormwall", server: emu_server)
      assert Character.find_by(name: "Asheron",   server: emu_server)
    end

    it "creates characters from a JSON array" do
      records = [
        { "name" => "Stormwall", "server" => emu_server },
        { "name" => "Asheron",   "server" => emu_server }
      ]
      post_characters(records.to_json, content_type: "application/json")

      assert_equal 202, last_response.status
      assert_equal 2, Character.count
    end

    it "creates an allegiance" do
      body = { "name" => "Knight", "server" => emu_server, "allegiance_name" => "Round Table" }.to_json
      post_characters(body)
      assert Allegiance.find_by(server: emu_server, name: "Round Table")
    end

    it "does not create characters from retail servers" do
      body = [
        { "name" => "Retail Guy", "server" => retail_server },
        { "name" => "Emu Player", "server" => emu_server }
      ].map(&:to_json).join("\n")

      post_characters(body)

      assert_equal 1, Character.count
      assert Character.find_by(name: "Emu Player")
    end

    it "decrements the inflight counter after the job completes" do
      body = { "name" => "Stormwall", "server" => emu_server }.to_json
      post_characters(body)
      assert_equal 0, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end

    it "does not leave temp files on disk" do
      body = { "name" => "Stormwall", "server" => emu_server }.to_json
      files_before = Dir.glob("/tmp/bulk_upload_*").sort

      post_characters(body)

      files_after = Dir.glob("/tmp/bulk_upload_*").sort
      assert_equal files_before, files_after
    end
  end
end
