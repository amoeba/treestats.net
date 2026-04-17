require_relative '../spec_helper'
require 'openssl'

describe BulkUploadHelper do
  let(:redis) { Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379") }

  before do
    redis.del(BulkUploadHelper::INFLIGHT_KEY)
    redis.del("#{BulkUploadHelper::RATE_LIMIT_KEY}:127.0.0.1")
    redis.del("#{BulkUploadHelper::RATE_LIMIT_KEY}:10.0.0.1")
  end

  # Build a minimal request-like object with a fixed env hash
  def fake_request(sig)
    env = sig ? { BulkUploadHelper::SIGNATURE_HEADER => sig } : {}
    Struct.new(:env).new(env)
  end

  def sign(body, secret)
    "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, body)}"
  end

  # ---------------------------------------------------------------------------
  describe ".valid_signature?" do
    let(:secret) { "treestats-test-secret" }
    let(:body)   { '{"name":"Stormwall","server":"Coldeve"}' }

    it "passes when BULK_UPLOAD_SECRET is not set" do
      without_env("BULK_UPLOAD_SECRET") do
        assert BulkUploadHelper.valid_signature?(fake_request("sha256=anything"), body)
      end
    end

    it "passes when BULK_UPLOAD_SECRET is empty" do
      with_env("BULK_UPLOAD_SECRET" => "") do
        assert BulkUploadHelper.valid_signature?(fake_request("sha256=anything"), body)
      end
    end

    it "passes with a correct HMAC-SHA256 signature" do
      with_env("BULK_UPLOAD_SECRET" => secret) do
        assert BulkUploadHelper.valid_signature?(fake_request(sign(body, secret)), body)
      end
    end

    it "fails when the signature does not match" do
      with_env("BULK_UPLOAD_SECRET" => secret) do
        refute BulkUploadHelper.valid_signature?(fake_request("sha256=deadbeef00"), body)
      end
    end

    it "fails when the signature header is missing" do
      with_env("BULK_UPLOAD_SECRET" => secret) do
        refute BulkUploadHelper.valid_signature?(fake_request(nil), body)
      end
    end

    it "fails when the header uses the wrong prefix" do
      with_env("BULK_UPLOAD_SECRET" => secret) do
        digest = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
        refute BulkUploadHelper.valid_signature?(fake_request("md5=#{digest}"), body)
      end
    end

    it "is sensitive to body content — a different body fails" do
      with_env("BULK_UPLOAD_SECRET" => secret) do
        sig = sign(body, secret)
        refute BulkUploadHelper.valid_signature?(fake_request(sig), body + " ")
      end
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
      BulkUploadHelper.decrement_inflight!
      assert_equal 2, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end

    it "round-trips correctly" do
      BulkUploadHelper.increment_inflight!(redis)
      BulkUploadHelper.increment_inflight!(redis)
      BulkUploadHelper.decrement_inflight!
      assert_equal 1, redis.get(BulkUploadHelper::INFLIGHT_KEY).to_i
    end
  end
end
