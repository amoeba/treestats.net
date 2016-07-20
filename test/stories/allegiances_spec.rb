require_relative '../story_helper.rb'

describe "AllegianceStory" do
  describe "POST / allegiances" do
    before do
      Character.all.destroy
      Allegiance.all.destroy
    end

    it "doesn't create empty allegiances" do
      post('/', '{"name":"testname", "server":"testserver"}')

      Allegiance.count.must_equal 0
    end

    it "creates allegiances" do
      post('/', '{"name":"testname", "server":"testserver", "attribs": {}, "allegiance_name": "someallegiance"}')

      Allegiance.count.must_equal 1
    end

    it "doesn't create duplicate allegiances" do
      post('/', '{"name":"testname", "server":"testserver", "attribs": {}, "allegiance_name":"someallegiance"}')
      post('/', '{"name":"testname", "server":"testserver", "attribs": {}, "allegiance_name":"someallegiance"}')

      Allegiance.count.must_equal 1
    end
  end
end
