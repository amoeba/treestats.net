# spec/unit/character.rb

require_relative '../spec_helper'

describe 'Character', :unit do
  before do
    Character.all.destroy
  end

  it "doesn't have to have a name" do
    assert_nil Character.create.name
  end

  it 'can have a name' do
    c = Character.create(name: 'TestChar')
    assert_equal c.name, 'TestChar'
  end

  it 'must have a name and server' do
    assert Character.create.invalid?
    assert Character.create(name: "somename").invalid?
    assert Character.create(server: "someserver").invalid?
    assert Character.create(name: "somename", server: "someserver").valid?
  end
end
