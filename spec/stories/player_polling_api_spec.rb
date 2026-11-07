require_relative "../story_helper"

describe "PlayerPollingApiStory" do
  before { PlayerCount.destroy_all }
  after { PlayerCount.destroy_all }

  it "keeps the original per-server JSON keys for legacy, plugin and server records" do
    [
      ["LegacyApi", {}],
      ["PluginApi", {r: "p"}],
      ["ServerApi", {r: "s"}],
      ["LegacyPluginApi", {source: "plugin"}],
      ["LegacyServerApi", {source: "server"}]
    ].each do |server, internal|
      PlayerCount.collection.insert_one({s: server, c: 4, c_at: Time.now.utc}.merge(internal))
      get "/player_counts/#{server}.json"
      assert_equal 200, last_response.status
      payload = JSON.parse(last_response.body)
      assert_equal %w[age count created_at server], payload.keys.sort
      refute payload.key?("source")
    end
  end
end
