# spec/unit/character.rb

require_relative '../spec_helper'

describe 'Character', :unit do
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
  
end