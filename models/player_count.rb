class PlayerCount
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short
  
  field :s, as: :server, type: String
  field :c, as: :count,  type: Integer
end