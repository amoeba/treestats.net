# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "CharacterStory" do
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

    it "assigns an account name if it's sent" do
      post('/account/create', '{"name":"test", "password" : "test"}')
      post('/', '{"name" : "Account Tester", "server":"test", "account_name" : "test"}')

      Character.find_by(name: "Account Tester").account_name.must_equal("test")
    end

    it "doesn't assign an account name if it's not sent" do
      post('/account/create', '{"name":"test", "password" : "test"}')
      post('/', '{"name" : "Account Tester", "server":"test"}')

      Character.find_by(name: "Account Tester").account_name.must_equal nil
    end

    it "sets patron race and gender correctly" do
      post('/', '{"name" : "patron", "server" : "test", "race" : "Aluvian", "gender" : "Male"}')
      Character.find_by(name: "patron")["name"].must_equal("patron")

      post('/', '{"name":"vassal", "server":"test", "patron" : {"name":"patron", "server" : "test", "race" : "1", "gender" : "1"}}')
      Character.find_by(name: "patron")["race"].must_equal("Aluvian")
      Character.find_by(name: "patron")["gender"].must_equal("Male")
    end

    it "sets vassal race and gender correctly" do
      post('/', '{"name" : "vassal", "server" : "test", "race" : "Aluvian", "gender" : "Male"}')

      post('/', '{"name":"vassal", "server":"test", "patron" : {"name":"patron", "server" : "test", "race" : "1", "gender" : "1"}}')

      Character.find_by(name: "vassal")["race"].must_equal("Aluvian")
      Character.find_by(name: "patron")["gender"].must_equal("Male")
    end

    it "sets monarch race and gender correctly" do
      post('/', '{"name" : "player", "server" : "test", "race" : "Aluvian", "gender" : "Male", '\
        '"monarch":{"name":"monarch","race":4,"rank":8,"gender":2,"followers":1105},'\
        '"patron":{"name":"patron","race":2,"rank":2,"gender":1},'\
        '"vassals":[{"name":"vassal_one", "server":"test", "race":1, "gender":1}]}')

      Character.find_by(name: "monarch").gender.must_equal "Female"
      Character.find_by(name: "monarch").race.must_equal "Viamontian"

      Character.find_by(name: "patron").gender.must_equal "Male"
      Character.find_by(name: "patron").race.must_equal "Gharu'ndim"

      Character.find_by(name: "vassal_one").gender.must_equal "Male"
      Character.find_by(name: "vassal_one").race.must_equal "Aluvian"
    end

    it "unsets a vassal from a patron when the vassal breaks then updates" do
      post('/', '{"name": "thevassal", "server": "test", "patron": {"name": "thepatron", "server": "test"}}')
      post('/', '{"name": "thepatron", "server": "test", "vassals": [{"name": "thevassal", "server": "test"}]}')
      post('/', '{"name": "thevassal", "server": "test", "patron": {"name": "newpatron", "server": "test"}}')

      chain = JSON.parse(get('/chain/test/thepatron').body)
      assert_equal(chain, {"name"=> "thepatron"})
    end


    it "maintains patron-vassal linkages after an update of the vassal" do
      post('/', '{"name": "thevassal", "server": "test", "patron": {"name": "thepatron", "server": "test"}}')
      post('/', '{"name": "thepatron", "server": "test", "vassals": [{"name": "thevassal", "server": "test"}]}')
      post('/', '{"name": "thevassal", "server": "test", "patron": {"name": "thepatron", "server": "test"}}')

      chain = JSON.parse(get('/chain/test/thepatron').body)
      assert_equal(chain, {"name"=> "thepatron", "children" => [ { "name" => "thevassal"}]})
    end

    it "maintains patron-multi-vassal linkages after an update of the vassal" do
      post('/', '{"name": "thepatron", "server": "test", "vassals": [{"name": "a", "server": "test"},{"name": "b", "server": "test"},{"name": "c", "server": "test"}]}')

      chain = JSON.parse(get('/chain/test/thepatron').body)
      assert_equal(chain, {"name"=>"thepatron", "children"=>[{"name"=>"a"}, {"name"=>"b"}, {"name"=>"c"}]})
    end
  end
end
