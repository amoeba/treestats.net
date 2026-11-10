require_relative "../story_helper"

describe "ServerStory" do
  before do
    PlayerCount.collection.delete_many(s: recent_counts_server)
  end

  after do
    PlayerCount.collection.delete_many(s: recent_counts_server)
  end

  it "keeps the online summary but removes the recent counts table and adds no history link" do
    PlayerCount.create!(server: recent_counts_server, count: 42)

    get "/#{recent_counts_server}"

    assert last_response.ok?
    assert_includes last_response.body, "Online"
    assert_includes last_response.body, "42"
    refute_includes last_response.body, "Recent Player Counts"
    refute_includes last_response.body, "<th>Source</th>"
    refute_includes last_response.body, "/servers/#{recent_counts_server}/player-counts"
  end

  it "serves an unlisted chart with source and combined controls, including a trailing slash" do
    ["", "/"].each do |suffix|
      get "/servers/#{recent_counts_server}/player-counts#{suffix}"

      assert last_response.ok?
      assert_equal "noindex, nofollow", last_response.headers["x-robots-tag"]
      assert_includes last_response.body, 'name="server"'
      assert_includes last_response.body, 'name="plugin"'
      assert_includes last_response.body, 'name="combined"'
      assert_includes last_response.body, "server_player_counts.js"
      assert_includes last_response.body, "/servers/#{recent_counts_server}/player-counts.json"
    end
  end

  it "escapes server names in the chart and encodes the data URL" do
    get "/servers/A%26B%20World/player-counts"

    assert last_response.ok?
    assert_includes last_response.body, "A&amp;B World"
    assert_includes last_response.body, "/servers/A%26B%20World/player-counts.json"
  end

  it "returns every raw observation within the two-week window in time order with normalized sources" do
    now = Time.now.utc
    since = now - 14 * 24 * 60 * 60
    records = [
      {c_at: since - 1, c: 999},
      {c_at: now + 60, c: 999},
      {c_at: now, c: 6, source: "server"},
      {c_at: now - 1, c: 5, source: "plugin"},
      {c_at: now - 2, c: 4, r: "s"},
      {c_at: now - 3, c: 3, r: "p"},
      {c_at: since + 60, c: 0}
    ]
    records.each { |record| PlayerCount.collection.insert_one(record.merge(s: recent_counts_server)) }

    get "/servers/#{recent_counts_server}/player-counts.json"

    assert last_response.ok?
    assert_equal "noindex, nofollow", last_response.headers["x-robots-tag"]
    data = JSON.parse(last_response.body)
    assert_in_delta now.to_f, Time.iso8601(data["end"]).to_f, 5
    assert_equal 14 * 24 * 60 * 60, Time.iso8601(data["end"]) - Time.iso8601(data["start"])
    assert_equal [0, 3, 4, 5, 6], data["observations"].map { |o| o["count"] }
    assert_equal %w[plugin plugin server plugin server], data["observations"].map { |o| o["source"] }
    data["observations"].each { |o| assert_equal %w[count source time], o.keys.sort }
  end

  it "does not truncate or aggregate raw observations" do
    now = Time.now.utc - 60
    60.times do |index|
      PlayerCount.collection.insert_one(s: recent_counts_server, c: index, c_at: now)
    end

    get "/servers/#{recent_counts_server}/player-counts.json"

    assert last_response.ok?
    observations = JSON.parse(last_response.body)["observations"]
    assert_equal 60, observations.length
    assert_equal (0...60).to_a, observations.map { |o| o["count"] }.sort
  end

  it "returns an empty observation list for a server without recent data" do
    get "/servers/#{recent_counts_server}/player-counts.json"

    assert last_response.ok?
    assert_equal [], JSON.parse(last_response.body)["observations"]
  end

  private

  def recent_counts_server
    "RecentCountsTest"
  end
end
