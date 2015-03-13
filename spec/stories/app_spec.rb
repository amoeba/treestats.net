# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "AppStory" do
  describe "GET /" do
    before do
      get '/'
    end

    it "responds successfully" do
      last_response.status.must_equal 200
    end
  end
  
  describe "POST / characters" do
    before do
      Character.all.destroy
    end
    
    it "reports update failure when the character isn't created" do
      post('/', '{}')
      last_response.body.must_equal "Character update failed."
    end
    
    it "creates simple characters successfully" do
      Character.count.must_equal 0
      
      post('/', '{"name":"test", "server":"test"}')
      
      Character.count.must_equal 1
      
      post('/', '{"name":"test2", "server":"test"}')
      last_response.body.must_equal "Character was updated successfully."
      
      post('/', '{"name":"test3", "server":"test"}')
      last_response.body.must_equal "Character was updated successfully."
      
      Character.count.must_equal 3
    end
    
    it "creates stub vassals" do
      post('/', '{"name":"patron", "server":"test","vassals":[{"name":"testvassal"}]}')
      last_response.body.must_equal "Character was updated successfully."
      
      Character.count.must_equal 2
    end
    
    it "creates stub vassals with patron set correctly" do
      post('/', '{"name":"patron", "server":"test","vassals":[{"name":"vassal"}]}')
      last_response.body.must_equal "Character was updated successfully."
      
      Character.find_by(name: 'vassal').patron['name'].must_equal "patron"
    end
    
    it "assigns monarch correctly" do
      post('/', '{"name":"patron", "server":"test","monarch":{"name":"monarch"},"vassals":[{"name":"vassal"}]}')
      last_response.body.must_equal "Character was updated successfully."
      
      Character.find_by(name: 'vassal').monarch['name'].must_equal "monarch"
    end
    
    it "assigns allegiance_name to all characters" do
      post('/', '{"name":"patron", "server":"test", "allegiance_name":"cool allegiance","monarch":{"name":"monarch"},"vassals":[{"name":"vassal"}]}')
      
      Character.find_by(name: 'monarch').allegiance_name.must_equal "cool allegiance"
      Character.find_by(name: 'patron').allegiance_name.must_equal "cool allegiance"
      Character.find_by(name: 'vassal').allegiance_name.must_equal "cool allegiance"
    end
  end  
  
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
      post('/', '{"name":"testname", "server":"testserver", "allegiance_name":"someallegiance"}')
      
      Allegiance.count.must_equal 1
    end
    
    it "doesn't create duplicate allegiances" do
      post('/', '{"name":"testname", "server":"testserver", "allegiance_name":"someallegiance"}')
      post('/', '{"name":"testname", "server":"testserver", "allegiance_name":"someallegiance"}')
      
      Allegiance.count.must_equal 1
    end
  end
end