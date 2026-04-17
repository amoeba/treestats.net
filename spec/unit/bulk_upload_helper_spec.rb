require_relative '../spec_helper'
require 'openssl'

describe BulkUploadHelper do
  let(:redis) { Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379") }

  before do
    redis.del(BulkUploadHelper::INFLIGHT_KEY)
    redis.del("#{BulkUploadHelper::RATE_LIMIT_KEY}:127.0.0.1")
    redis.del("#{BulkUploadHelper::RATE_LIMIT_KEY}:10.0.0.1")
    ApiKey.all.destroy
    Account.all.destroy
  end

  # Build a minimal request-like object with a fixed env hash
  def fake_request(env = {})
    Struct.new(:env).new(env)
  end

  def sign(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
  end

  # ---------------------------------------------------------------------------
  describe ".valid_signature?" do
    let(:body) { { "name" => "Stormwall", "server" => "TestServer" }.to_json }
    let(:account) { Account.create!(name: "TestUser", password: "pass") }
    let(:api_key) { ApiKey.create!(account: account) }

    it "passes with a correct HMAC-SHA256 signature" do
      env = {
        BulkUploadHelper::API_KEY_HEADER   => api_key.secret,
        BulkUploadHelper::SIGNATURE_HEADER => sign(body, api_key.secret)
      }
      assert BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the signature does not match" do
      env = {
        BulkUploadHelper::API_KEY_HEADER   => api_key.secret,
        BulkUploadHelper::SIGNATURE_HEADER => "sha256=deadbeef00"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the signature header is missing" do
      env = { BulkUploadHelper::API_KEY_HEADER => api_key.secret }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the api key header is missing" do
      env = { BulkUploadHelper::SIGNATURE_HEADER => sign(body, api_key.secret) }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the token has the wrong prefix" do
      bad_token = "xx_#{account.id}#{SecureRandom.hex(32)}"
      env = {
        BulkUploadHelper::API_KEY_HEADER   => bad_token,
        BulkUploadHelper::SIGNATURE_HEADER => "sha256=anything"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when no ApiKey exists for the account encoded in the token" do
      other_account = Account.create!(name: "OtherUser", password: "pass")
      fake_token = "ts_#{other_account.id}#{SecureRandom.hex(32)}"
      env = {
        BulkUploadHelper::API_KEY_HEADER   => fake_token,
        BulkUploadHelper::SIGNATURE_HEADER => "sha256=anything"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the signature uses the wrong prefix" do
      digest = OpenSSL::HMAC.hexdigest("SHA256", api_key.secret, body)
      env = {
        BulkUploadHelper::API_KEY_HEADER   => api_key.secret,
        BulkUploadHelper::SIGNATURE_HEADER => "md5=#{digest}"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "is sensitive to body content — a different body fails" do
      env = {
        BulkUploadHelper::API_KEY_HEADER   => api_key.secret,
        BulkUploadHelper::SIGNATURE_HEADER => sign(body, api_key.secret)
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body + " ")
    end
  end

  # ---------------------------------------------------------------------------
  describe ".over_rate_limit?" do
    it "returns false on the first request" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "3") do
        refute BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1")
      end
    end

    it "returns false while under the limit" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "3") do
        2.times { BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1") }
        refute BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1")
      end
    end

    it "returns true once the limit is exceeded" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "3") do
        3.times { BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1") }
        assert BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1")
      end
    end

    it "tracks different IPs independently" do
      with_env("BULK_UPLOAD_RATE_LIMIT" => "1") do
        BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1") # hits limit
        assert BulkUploadHelper.over_rate_limit?(redis, "127.0.0.1")
        refute BulkUploadHelper.over_rate_limit?(redis, "10.0.0.1") # different IP, fresh
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe ".try_increment_inflight!" do
    it "returns true and increments when under the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        assert BulkUploadHelper.try_increment_inflight!(redis)
        assert_equal 1, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
      end
    end

    it "returns true when reaching the limit exactly" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 4)
        assert BulkUploadHelper.try_increment_inflight!(redis)
        assert_equal 5, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
      end
    end

    it "returns false and does not increment when at the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 5)
        refute BulkUploadHelper.try_increment_inflight!(redis)
        assert_equal 5, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
      end
    end

    it "increments additively while under the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        3.times { BulkUploadHelper.try_increment_inflight!(redis) }
        assert_equal 3, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe ".decrement_inflight!" do
    it "decrements the counter" do
      redis.set(BulkUploadHelper::INFLIGHT_KEY, 3)
      BulkUploadHelper.decrement_inflight!(redis)
      assert_equal 2, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end

    it "round-trips correctly with try_increment_inflight!" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        BulkUploadHelper.try_increment_inflight!(redis)
        BulkUploadHelper.try_increment_inflight!(redis)
        BulkUploadHelper.decrement_inflight!(redis)
        assert_equal 1, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
      end
    end
  end
end
