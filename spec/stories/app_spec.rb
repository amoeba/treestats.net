# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "AppStory" do
  describe "GET /" do
    before do
      get('/')
    end

    it "responds successfully" do
      assert_equal last_response.status, 200
    end
  end

  describe "some routes are reachable" do
    before do
      Character.create({ "name" => 'some patron', "server" => "Frostfell"})
    end

    it "can reach the index" do
      get('/')
      assert_equal last_response.status, 200
    end

    it "can reach the the allegiances listing" do
      get('/allegiances')
      assert_equal last_response.status, 200
    end

    it "can reach the characters listing" do
      get('/characters')
      assert_equal last_response.status, 200
    end

    it "can reach the listing for Frostfell" do
      get('/Frostfell')
      assert_equal last_response.status, 200
    end

    it "can reach the titles listing" do
      get("/titles")
      assert_equal last_response.status, 200
    end
  end
end
