require_relative '../spec_helper'

describe 'Character', :unit do
  before do
    Character.all.destroy
  end

  it "doesn't have to have a name" do
    Character.create.name.must_equal nil
  end

  it 'can have a name' do
    c = Character.create(name: 'TestChar')
    c.name.must_equal 'TestChar'
  end

  it 'must have a name and server' do
    Character.create.must_be :invalid?
    Character.create(name: "somename").must_be :invalid?
    Character.create(server: "someserver").must_be :invalid?
    Character.create(name: "somename", server: "someserver").must_be :valid?
  end

  it 'creates vassals for itself' do
    Character.create({"name" => 'some patron', "server" => "test", "vassals" => [{"name" => "vassalA"}, {"name" => "vassalB"}, {"name" => "vassalC"}]})
    Character.count.must_equal 4
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

  it "fires the post-save monarch creation" do
    c = Character.create({:name => "somechar", :server => 'someserver', :monarch => {"name" => "somemonarch"}})

    Character.count.must_equal 2
    Character.find_by(name: "somechar", server: "someserver").wont_be :nil?
    Character.find_by(name: "somemonarch", server: "someserver").wont_be :nil?
  end

  it "sets nil rank/race/gender when we don't specify them" do
    c = Character.create({:name => "somechar", :server => 'someserver', :monarch => {"name" => "somemonarch"}})

    c.monarch['rank'].must_equal nil
    c.monarch['race'].must_equal 0
    c.monarch['gender'].must_equal 0
  end

  it "sets values for rank/race/gender when we secify them" do
    c = Character.create({:name => "somechar", :server => 'someserver', :monarch => {"name" => "somemonarch", "rank" => 5, "race" => 2, "gender" => 1}})

    c.monarch['rank'].must_equal 5
    c.monarch['race'].must_equal "Gharu'ndim"
    c.monarch['gender'].must_equal "Male"
  end

  it "sets values for vassals rank/race/gender when we secify them" do
    c = Character.create({
      :name => "somechar",
      :server => 'someserver',
      :monarch => {"name" => "somemonarch", "rank" => 5, "race" => 2, "gender" => 1},
      :vassals => [
        {'name' => 'vassal', 'rank' => 2, 'race' => 3, 'gender' => 1}]})

    c.monarch['rank'].must_equal 5
    # c.monarch['race'].must_equal "Gharu'ndim"
    # c.monarch['gender'].must_equal "Male"

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

    Character.count.must_equal 3

    middle = Character.find_by(name: "Pew the Mottled", server: "testserver")

    middle.patron["name"].must_equal "Mr Adventure"
    middle.vassals.length.must_equal 1
    middle.vassals.first["name"].must_equal "Barbados"
  end


  it "removes a patron-vassal link when the vassal breaks" do
    Character.create(name: "patron", server: "test")
    Character.create({
      "name" => "vassal",
      "server" => "test",
      "patron" => {
        "name" => "patron"
       }
    })

    patron = Character.find_by(name: "patron", server: "test")
    assert_includes patron.vassals.map { |v| v["name"]}, "vassal"

    Character.create({
      "name" => "vassal",
      "server" => "test",
      "attribs" => {}
    })

    patron = Character.find_by(name: "patron", server: "test")
    patron.vassals.length.must_equal 0
  end

  it "removes the char of outdated vassals" do
    Character.create({
      "name" => "patron",
      "server" => "test",
      "attribs" => {},
      "vassals" => [{
        "name" => "vassal",
        "gender" => "1",
        "race" => "1",
        "rank" => "1"
       }]
    })

    Character.where(name: "patron", server: "test").count.must_equal 1
    Character.where(name: "vassal", server: "test").count.must_equal 1

    vassal = Character.find_by(name: "vassal", server: "test")
    vassal.patron['name'].must_equal "patron"

    patron = Character.find_by(name: "patron", server: "test")
    patron.vassals[0]['name'].must_equal 'vassal'
  end
end
