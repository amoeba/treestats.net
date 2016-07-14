require_relative '../story_helper.rb'

describe "StatsStory" do
  before do
    redis.set "uploads.monthly.201505", 0
  end
end
