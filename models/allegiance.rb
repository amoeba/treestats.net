class Allegiance
  include Mongoid::Document
  include Mongoid::Timestamps::Short
  
  field :s,   as: :server,  type: String
  field :n,   as: :name,    type: String
end