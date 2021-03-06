# spec/stories/tree_spec

describe "ChainStory" do
  before do
    Character.all.destroy
  end

  it "can generate a simple chain" do
    Character.create({"name" => 'some patron', "server" => "test", "vassals" => [{"name" => "vassalA"}, {"name" => "vassalB"}, {"name" => "vassalC"}]})
    assert_equal AllegianceChain.new("test", "some patron").get_chain, {"name"=>"some patron", "children"=>[{"name"=>"vassalA"}, {"name"=>"vassalB"}, {"name"=>"vassalC"}]}
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

    chain = AllegianceChain.new("testserver", "Barbados").get_chain
    assert_equal chain, {"name"=>"Mr Adventure", "children"=>[{"name"=>"Pew the Mottled", "children"=>[{"name"=>"Barbados"}]}]}
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

    chain = AllegianceChain.new("testserver", "Barbados").get_chain
    assert_equal chain, {"name"=>"Mr Adventure", "children"=>[{"name"=>"Pew the Mottled", "children"=>[{"name"=>"Barbados"}]}]}
  end

  it "connects distance relationships when characters when uploaded as JSON" do
    post('/', '{"name":"Mr Adventure", "server":"test", "vassals":[{"name":"Pew the Mottled"}]}')
    post('/', '{"name":"Barbados", "server":"test", "patron":{"name":"Pew the Mottled"}}')

    assert_equal Character.count, 3

    chain = AllegianceChain.new("test", "Barbados").get_chain
    assert_equal chain, {"name"=>"Mr Adventure", "children"=>[{"name"=>"Pew the Mottled", "children"=>[{"name"=>"Barbados"}]}]}
  end
end
