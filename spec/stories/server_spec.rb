require_relative "../story_helper"

describe "ServerStory" do
  before do
    PlayerCount.collection.delete_many(s: recent_counts_server)
  end

  after do
    PlayerCount.collection.delete_many(s: recent_counts_server)
  end

  it "shows the 50 most recent player counts in reverse chronological order" do
    now = Time.now.utc

    51.times do |index|
      PlayerCount.collection.insert_one({
        s: recent_counts_server,
        c: 100 + index,
        c_at: now - (50 - index),
        r: index.even? ? PlayerCount::PLUGIN_SOURCE : PlayerCount::SERVER_SOURCE
      })
    end

    get "/#{recent_counts_server}"

    assert last_response.ok?
    assert_includes last_response.body, "Recent Player Counts"
    assert_includes last_response.body, '<table class="listing auto">'
    assert_includes last_response.body, "<th>Source</th>"
    assert_includes last_response.body, "Plugin"
    assert_includes last_response.body, "Server poll"
    refute_includes last_response.body, "<td>100</td>"
    assert_operator last_response.body.index("<td>150</td>"), :<, last_response.body.index("<td>149</td>")
    assert_operator last_response.body.index("No characters to display"), :<,
      last_response.body.index("Recent Player Counts")
  end

  private

  def recent_counts_server
    "RecentCountsTest"
  end
end
