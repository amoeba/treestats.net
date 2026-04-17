require_relative '../spec_helper'

describe ApiKey do
  before do
    ApiKey.all.destroy
    Account.all.destroy
  end

  let(:account) { Account.create!(name: "TestUser", password: "pass") }

  describe "secret generation" do
    it "generates a secret on create" do
      key = ApiKey.create!(account: account)
      refute_nil key.secret
    end

    it "uses the ts_ prefix" do
      key = ApiKey.create!(account: account)
      assert key.secret.start_with?("ts_")
    end

    it "embeds the account id immediately after the prefix" do
      key = ApiKey.create!(account: account)
      embedded = key.secret[BulkUploadHelper::TOKEN_PREFIX.length, BulkUploadHelper::ACCOUNT_ID_LEN]
      assert_equal account.id.to_s, embedded
    end

    it "appends 64 hex chars of random data after the account id" do
      key = ApiKey.create!(account: account)
      random_part = key.secret[(BulkUploadHelper::TOKEN_PREFIX.length + BulkUploadHelper::ACCOUNT_ID_LEN)..]
      assert_equal 64, random_part.length
      assert_match(/\A[0-9a-f]+\z/, random_part)
    end

    it "produces a unique secret each time" do
      account2 = Account.create!(name: "OtherUser", password: "pass")
      k1 = ApiKey.create!(account: account)
      k2 = ApiKey.create!(account: account2)
      refute_equal k1.secret, k2.secret
    end

    it "does not regenerate the secret on subsequent saves" do
      key = ApiKey.create!(account: account)
      original = key.secret
      key.save!
      assert_equal original, key.reload.secret
    end
  end
end
