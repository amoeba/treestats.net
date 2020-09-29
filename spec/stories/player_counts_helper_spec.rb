require_relative '../story_helper.rb'

describe "PlayerCountsStory" do
  describe "GET / player_counts" do

    it "can get some player counts" do
      get "/player_counts.json"
      assert last_response.ok?

      get "/player_counts.json?servers=All"
      assert last_response.ok?

      get "/player_counts?servers=All&range=6mo"
      assert last_response.ok?
    end

    it "can fail some bad requests" do
      get "/player_counts.json?servers=foo"
      assert !last_response.ok?

      get "/player_counts.json?servers=All&range=waht"
      assert !last_response.ok?

      get "/player_counts.json?servers=who&range=3mo"
      assert !last_response.ok?
    end
  end
end
