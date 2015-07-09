# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "AppStory" do
  describe "GET /" do
    before do
      get('/')
    end

    it "responds successfully" do
      last_response.status.must_equal 200
    end
  end
end
