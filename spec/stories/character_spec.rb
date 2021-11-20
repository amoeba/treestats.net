# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "CharacterStory" do
  describe "POST / characters" do
    before do
      Character.all.destroy
    end

    # chain scenarios involving mutating another character
    #
    # monarch
    # creates a monarch stub if needed
    # updates monarch stub's information (race/gender)
    # updates monarch information if needed
    # [do nothing if the monarch isn't set]
    #
    # patron
    # creates a patron stub if needed
    # updates patron stub's information (race/gender)
    # sets the current char as a vassal on the patron
    # [if patron is not set]
    # remove player from patron's vassals
    #
    # vassals
    # creates vassal stub(s) if needed
    # updates vassal stub's (race/gender)
    #
    # does a difference between what vassals were sent
    # and what vassals are stored
    # updates ones that are still included
    # updates patron field on ones that are not
    #

    it "reports update failure when the character isn't created" do
      post('/', '{}')
      assert_equal last_response.body, "Character update failed."
    end

    it "reports that levels 1 can't be uploaded with phatac temporarily" do
      post('/', '{"name":"", "server": "myserver"}')
      assert_equal last_response.body, "Level 1 characters can't be uploaded with PhatAC currently. Sorry!"
    end


    it "creates simple characters successfully" do
      assert_equal Character.count, 0

      post('/', '{"name":"test", "server":"test"}')

      assert_equal Character.count, 1

      post('/', '{"name":"test2", "server":"test"}')
      assert_equal last_response.body, "Character was updated successfully."

      post('/', '{"name":"test3", "server":"test"}')
      assert_equal last_response.body, "Character was updated successfully."

      assert_equal Character.count, 3
    end

    it "creates stub vassals" do
      post('/', '{"name":"patron", "server":"test","vassals":[{"name":"testvassal"}]}')
      assert_equal last_response.body, "Character was updated successfully."

      assert_equal Character.count, 2
    end

    it "creates stub vassals with patron set correctly" do
      post('/', '{"name":"patron", "server":"test","vassals":[{"name":"vassal"}]}')
      assert_equal last_response.body, "Character was updated successfully."

      assert_equal Character.find_by(name: 'vassal').patron['name'], "patron"
    end

    it "assigns monarch correctly" do
      post('/', '{"name":"patron", "server":"test","monarch":{"name":"monarch"},"vassals":[{"name":"vassal"}]}')
      assert_equal last_response.body, "Character was updated successfully."

      assert_equal Character.find_by(name: 'vassal').monarch['name'], "monarch"
    end

    it "assigns allegiance_name to all characters" do
      post('/', '{"name":"patron", "server":"test", "allegiance_name":"cool allegiance","monarch":{"name":"monarch"},"vassals":[{"name":"vassal"}]}')

      assert_equal Character.find_by(name: 'monarch').allegiance_name, "cool allegiance"
      assert_equal Character.find_by(name: 'patron').allegiance_name, "cool allegiance"
      assert_equal Character.find_by(name: 'vassal').allegiance_name, "cool allegiance"
    end

    it "assigns an account name if it's sent" do
      post('/account/create', '{"name":"test", "password" : "test"}')
      post('/', '{"name" : "Account Tester", "server":"test", "account_name" : "test"}')

      assert_equal Character.find_by(name: "Account Tester").account_name,("test")
    end

    it "doesn't assign an account name if it's not sent" do
      post('/account/create', '{"name":"test", "password" : "test"}')
      post('/', '{"name" : "Account Tester", "server":"test"}')

      assert_nil Character.find_by(name: "Account Tester").account_name
    end

    it "sets patron race and gender correctly" do
      post('/', '{"name" : "patron", "server" : "test", "race" : "Aluvian", "gender" : "Male"}')
      assert_equal Character.find_by(name: "patron")["name"],("patron")

      post('/', '{"name":"vassal", "server":"test", "patron" : {"name":"patron", "server" : "test", "race" : "1", "gender" : "1"}}')
      assert_equal Character.find_by(name: "patron")["race"],("Aluvian")
      assert_equal Character.find_by(name: "patron")["gender"],("Male")
    end

    it "sets vassal race and gender correctly" do
      post('/', '{"name" : "vassal", "server" : "test", "race" : "Aluvian", "gender" : "Male"}')

      post('/', '{"name":"vassal", "server":"test", "patron" : {"name":"patron", "server" : "test", "race" : "1", "gender" : "1"}}')

      assert_equal Character.find_by(name: "vassal")["race"],("Aluvian")
      assert_equal Character.find_by(name: "patron")["gender"],("Male")
    end

    it "sets monarch race and gender correctly" do
      post('/', '{"name" : "player", "server" : "test", "race" : "Aluvian", "gender" : "Male", '\
        '"monarch":{"name":"monarch","race":4,"rank":8,"gender":2,"followers":1105},'\
        '"patron":{"name":"patron","race":2,"rank":2,"gender":1},'\
        '"vassals":[{"name":"vassal_one", "server":"test", "race":1, "gender":1}]}')

      assert_equal Character.find_by(name: "monarch").gender, "Female"
      assert_equal Character.find_by(name: "monarch").race, "Viamontian"

      assert_equal Character.find_by(name: "patron").gender, "Male"
      assert_equal Character.find_by(name: "patron").race, "Gharu'ndim"

      assert_equal Character.find_by(name: "vassal_one").gender, "Male"
      assert_equal Character.find_by(name: "vassal_one").race, "Aluvian"
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

    it "removes monarch when an update comes in without one" do
      post('/', '{"name": "some char", "server": "test", "monarch": {"name": "some monarch"}}')
      assert_equal Character.find_by(name: "some char").monarch["name"], "some monarch"
      post('/', '{"name": "some char", "server": "test"}')
      assert_nil Character.find_by(name: "some char").monarch
    end

    it "removes patron when an update comes in without one" do
      post('/', '{"name": "some char", "server": "test", "patron": {"name": "some patron"}}')
      assert_equal Character.find_by(name: "some char").patron["name"], "some patron"
      post('/', '{"name": "some char", "server": "test"}')
      assert_nil Character.find_by(name: "some char").patron
    end

    it "removes vassals when an update comes in without one" do
      post('/', '{"name": "some char", "server": "test", "vassals": [{"name": "vassal one"}]}')
      assert_equal Character.find_by(name: "some char").vassals[0]["name"], "vassal one"
      post('/', '{"name": "some char", "server": "test"}')
      assert_nil Character.find_by(name: "some char").vassals
    end
  end

  describe "Character.to_json" do
    it "filters out id and ip_address" do
      post('/', '{"name" : "player", "server" : "test", "ip_address": "127.0.0.1"}')

      c = Character.find_by(name: "player", server: "test")
      json = c.to_json

      assert !json.include?("_id")
      assert !json.include?("ip_address")

      resp = get("/test/player.json")

      assert resp.body.include?("player")
      assert !resp.body.include?("ip_adderss")
    end
  end
end
