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

  describe "some routes are reachable" do
    it "can reach the index" do
      get('/')
      last_response.status.must_equal 200
    end

    it "can reach the the allegiances listing" do
      get('/allegiances')
      last_response.status.must_equal 200
    end

    it "can reach the characters listing" do
      get('/characters')
      last_response.status.must_equal 200
    end

    it "can reach the listing for Frostfell" do
      get('/Frostfell')
      last_response.status.must_equal 200
    end
  end
end
