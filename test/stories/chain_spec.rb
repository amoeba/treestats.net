# spec/stories/tree_spec

describe "ChainStory" do
  before do
    Character.all.destroy
  end

  it "can generate a simple chain" do
    Character.create({"name" => 'some patron', "server" => "test", "vassals" => [{"name" => "vassalA"}, {"name" => "vassalB"}, {"name" => "vassalC"}]})
    Chain.new("test", "some patron").get_chain.must_equal({"name"=>"some patron", "children"=>[{"name"=>"vassalA"}, {"name"=>"vassalB"}, {"name"=>"vassalC"}]})
  end

  it "connects distance relationships" do
    super_patron = Character.create({
      "name" => "Mr Adventure",
      "server" => "testserver",
      "vassals" => [ {
        "name" => "Pew the Mottled"
        }]
      })

    character = Character.create({
      "name" => "Barbados",
      "server" => "testserver",
      "patron" => { "name" => "Pew the Mottled"}
      })

    chain = Chain.new("testserver", "Barbados").get_chain
    chain.must_equal({"name"=>"Mr Adventure", "children"=>[{"name"=>"Pew the Mottled", "children"=>[{"name"=>"Barbados"}]}]})
  end

  it "connects distance relationships when characters are updated in the other order" do
    character = Character.create({
      "name" => "Barbados",
      "server" => "testserver",
      "patron" => { "name" => "Pew the Mottled"}
      })


    super_patron = Character.create({
      "name" => "Mr Adventure",
      "server" => "testserver",
      "vassals" => [ {
        "name" => "Pew the Mottled"
        }]
      })

    chain = Chain.new("testserver", "Barbados").get_chain
    chain.must_equal({"name"=>"Mr Adventure", "children"=>[{"name"=>"Pew the Mottled", "children"=>[{"name"=>"Barbados"}]}]})
  end

  it "connects distance relationships when characters when uploaded as JSON" do
    post('/', '{"name":"Mr Adventure", "server":"test", "vassals":[{"name":"Pew the Mottled"}]}')
    post('/', '{"name":"Barbados", "server":"test", "patron":{"name":"Pew the Mottled"}}')

    Character.count.must_equal 3

    chain = Chain.new("test", "Barbados").get_chain
    chain.must_equal({"name"=>"Mr Adventure", "children"=>[{"name"=>"Pew the Mottled", "children"=>[{"name"=>"Barbados"}]}]})
  end

  it "gracefully handles a circular patron reference" do
    post('/', '{"name":"B", "server":"test", "patron":{"name":"A"}}')
    post('/', '{"name":"A", "server":"test", "patron":{"name":"C"}}')
    post('/', '{"name":"C", "server":"test", "patron":{"name":"B"}}')

    get('/chain/test/B')
    last_response.status.must_equal 200
  end

  it "gracefully handles a circular vassal reference" do
    post('/', '{"name":"A", "server":"test", "vassals":[{"name":"B"}]}')
    post('/', '{"name":"B", "server":"test", "vassals":[{"name":"A"}]}')

    get('/chain/test/B')
    last_response.status.must_equal 200
  end
end
