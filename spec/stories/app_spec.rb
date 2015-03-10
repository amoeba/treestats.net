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
  
  describe "POST /" do
    before do
      Character.all.destroy
    end
          
    it "creates simple characters successfully" do
      Character.count.must_equal 0
      
      post('/', '{"name":"test", "server":"test"}')
      
      Character.count.must_equal 1
      
      post('/', '{"name":"test2", "server":"test"}')
      post('/', '{"name":"test3", "server":"test"}')
      
      Character.count.must_equal 3
    end
    
    it "creates stub vassals" do
      post('/', '{"name":"patron", "server":"test","vassals":[{"name":"testvassal"}]}')
      
      Character.count.must_equal 2
    end
    
    it "creates stub vassals with patron set correctly" do
      post('/', '{"name":"patron", "server":"test","vassals":[{"name":"vassal"}]}')
      
      Character.find_by(name: 'vassal').patron['name'].must_equal "patron"
    end
    
    it "assigns monarch correctly" do
      post('/', '{"name":"patron", "server":"test","monarch":{"name":"monarch"},"vassals":[{"name":"vassal"}]}')
      
      Character.find_by(name: 'vassal').monarch['name'].must_equal "monarch"
    end
    
    it "assigns allegiance_name to all characters" do
      post('/', '{"name":"patron", "server":"test", "allegiance_name":"cool allegiance","monarch":{"name":"monarch"},"vassals":[{"name":"vassal"}]}')
      
      Character.find_by(name: 'monarch').allegiance_name.must_equal "cool allegiance"
      Character.find_by(name: 'patron').allegiance_name.must_equal "cool allegiance"
      Character.find_by(name: 'vassal').allegiance_name.must_equal "cool allegiance"
    end
    
    it "fires the post-save monarch creation" do
      c = Character.create({:name => "somechar", :server => 'someserver', :monarch => {"name" => "somemonarch"}})
      
      Character.count.must_equal 2
      Character.find_by(name: "somechar", server: "someserver").wont_be :nil?
      Character.find_by(name: "somemonarch", server: "someserver").wont_be :nil?
    end
    
    it "sets nil rank/race/gender when we don't specify them" do
      c = Character.create({:name => "somechar", :server => 'someserver', :monarch => {"name" => "somemonarch"}})

      c.monarch['rank'].must_equal nil
      c.monarch['race'].must_equal nil
      c.monarch['gender'].must_equal nil
    end
    
    it "sets values for rank/race/gender when we secify them" do
      c = Character.create({:name => "somechar", :server => 'someserver', :monarch => {"name" => "somemonarch", "rank" => 5, "race" => 2, "gender" => 1}})

      c.monarch['rank'].must_equal 5
      c.monarch['race'].must_equal 2
      c.monarch['gender'].must_equal 1
    end
    
    it "sets values for vassals rank/race/gender when we secify them" do
      c = Character.create({
        :name => "somechar", 
        :server => 'someserver', 
        :monarch => {"name" => "somemonarch", "rank" => 5, "race" => 2, "gender" => 1},
        :vassals => [
          {'name' => 'vassal', 'rank' => 2, 'race' => 3, 'gender' => 1}]})

      c.monarch['rank'].must_equal 5
      c.monarch['race'].must_equal 2
      c.monarch['gender'].must_equal 1
      
      v = Character.find_by(name: 'vassal')
      
      v.monarch['name'].must_equal 'somemonarch'
      v.rank.must_equal 2
    end
    
    it "pushes the current character as a vassal to the patron" do
      c = Character.create({
        :name => 'char',
        :server => 'test',
        :patron => { "name" => "patron" }
        })
      
      p = Character.find_by(name: 'patron', server: 'test')
      
      p.vassals.must_be_kind_of Array
      p.vassals.wont_be :nil?
      p.vassals.detect { |v| v["name"]}.wont_be :nil?
    end
    
    it "can add character as vassal to their patron when the patron already has a vassal" do
      c = Character.create({
        :name => "char",
        :server => "test",
        :patron => { "name" => "patron" }
        })
      
      Character.create({
        :name => "anotherchar",
        :server => "test",
        :patron => {"name" => "patron"}
        })
      
      p = Character.find_by({
        :name => "patron",
        :server => "test"
        })
      
      p.vassals.length.must_equal 2
      p.vassals.collect { |v| v["name"] }.must_equal ["char", "anotherchar"]
    end
  end
end