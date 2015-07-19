# spec/stories/stats_spec.rb

require_relative '../story_helper.rb'

describe "StatsStory" do
  before do
    redis.set "uploads.monthly.201505", 0
  end
  
  describe "it can increase a stat" do
    # settings.redis.incr "uploads.monthly.201505"
    # app.redis.get("uploads.monthly.201505").must_equal(1)
  end
  
end
