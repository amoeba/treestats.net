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
        c_at: now - (50 - index)
      })
    end

    get "/#{recent_counts_server}"

    assert last_response.ok?
    assert_includes last_response.body, "Recent Player Counts"
    refute_includes last_response.body, "<td>100</td>"
    assert_operator last_response.body.index("<td>150</td>"), :<, last_response.body.index("<td>149</td>")
  end

  private

  def recent_counts_server
    "RecentCountsTest"
  end
end
