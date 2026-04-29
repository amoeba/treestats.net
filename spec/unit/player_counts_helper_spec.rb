require_relative '../spec_helper'

describe 'PlayerCountsHelper', :unit do
  before do
    PlayerCount.all.destroy
  end

  describe "date boundary" do
    before do
      now_utc = Time.now.utc
      @today_midnight_utc     = Time.utc(now_utc.year, now_utc.month, now_utc.day)
      @yesterday_midnight_utc = @today_midnight_utc - 86400

      # Use the collection API to set c_at explicitly, bypassing the Mongoid
      # timestamp callback which would overwrite it with Time.now.
      PlayerCount.collection.insert_one({ s: "TestServer", c: 100, c_at: @yesterday_midnight_utc + 3600 })
      PlayerCount.collection.insert_one({ s: "TestServer", c: 200, c_at: @today_midnight_utc   + 3600 })
    end

    it "excludes today's data" do
      result = JSON.parse(player_counts(["TestServer"], "All"))
      today_str = @today_midnight_utc.strftime("%Y%m%d")
      assert result.none? { |r| r["date"] == today_str }, "today's data should not appear"
    end

    it "includes yesterday's data" do
      result = JSON.parse(player_counts(["TestServer"], "All"))
      yesterday_str = @yesterday_midnight_utc.strftime("%Y%m%d")
      refute_empty result.select { |r| r["date"] == yesterday_str }, "yesterday's data should appear"
    end
  end
end
