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
    let(:body) { '{"name":"Stormwall","server":"Coldeve"}' }
    let(:account) { Account.create!(name: "TestUser", password: "pass") }
    let(:api_key) { ApiKey.create!(account: account) }

    it "passes with a correct HMAC-SHA256 signature" do
      env = {
        BulkUploadHelper::ACCOUNT_ID_HEADER => account.id.to_s,
        BulkUploadHelper::SIGNATURE_HEADER  => sign(body, api_key.secret)
      }
      assert BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the signature does not match" do
      env = {
        BulkUploadHelper::ACCOUNT_ID_HEADER => account.id.to_s,
        BulkUploadHelper::SIGNATURE_HEADER  => "sha256=deadbeef00"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the signature header is missing" do
      env = { BulkUploadHelper::ACCOUNT_ID_HEADER => account.id.to_s }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the account_id header is missing" do
      env = { BulkUploadHelper::SIGNATURE_HEADER => sign(body, api_key.secret) }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when no ApiKey exists for the account" do
      other_account = Account.create!(name: "OtherUser", password: "pass")
      env = {
        BulkUploadHelper::ACCOUNT_ID_HEADER => other_account.id.to_s,
        BulkUploadHelper::SIGNATURE_HEADER  => "sha256=anything"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "fails when the header uses the wrong prefix" do
      digest = OpenSSL::HMAC.hexdigest("SHA256", api_key.secret, body)
      env = {
        BulkUploadHelper::ACCOUNT_ID_HEADER => account.id.to_s,
        BulkUploadHelper::SIGNATURE_HEADER  => "md5=#{digest}"
      }
      refute BulkUploadHelper.valid_signature?(fake_request(env), body)
    end

    it "is sensitive to body content — a different body fails" do
      env = {
        BulkUploadHelper::ACCOUNT_ID_HEADER => account.id.to_s,
        BulkUploadHelper::SIGNATURE_HEADER  => sign(body, api_key.secret)
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
  describe ".over_inflight_limit?" do
    it "returns false when no jobs are in flight" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        refute BulkUploadHelper.over_inflight_limit?(redis)
      end
    end

    it "returns false when below the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 4)
        refute BulkUploadHelper.over_inflight_limit?(redis)
      end
    end

    it "returns true when at the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 5)
        assert BulkUploadHelper.over_inflight_limit?(redis)
      end
    end

    it "returns true when over the limit" do
      with_env("BULK_UPLOAD_MAX_INFLIGHT" => "5") do
        redis.set(BulkUploadHelper::INFLIGHT_KEY, 99)
        assert BulkUploadHelper.over_inflight_limit?(redis)
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe ".increment_inflight! and .decrement_inflight!" do
    it "increments the counter" do
      BulkUploadHelper.increment_inflight!(redis)
      assert_equal 1, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end

    it "increments additively" do
      3.times { BulkUploadHelper.increment_inflight!(redis) }
      assert_equal 3, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end

    it "decrements the counter" do
      redis.set(BulkUploadHelper::INFLIGHT_KEY, 3)
      BulkUploadHelper.decrement_inflight!(redis)
      assert_equal 2, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end

    it "round-trips correctly" do
      BulkUploadHelper.increment_inflight!(redis)
      BulkUploadHelper.increment_inflight!(redis)
      BulkUploadHelper.decrement_inflight!(redis)
      assert_equal 1, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end
  end
end
