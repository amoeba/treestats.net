# spec/stories/tree_spec

describe "TreeStory" do
  it "can generate a simple tree" do
    Character.create({:name => 'some patron', :vassals => [{:name => "vassal1"}, {:name => "vassal2"}, {:name => "vassal3"}]})
    
    
  end
end