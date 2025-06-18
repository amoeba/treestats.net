class Allegiance
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  validates_presence_of :server
  validates_presence_of :name

  field :s,   as: :server,  type: String
  field :n,   as: :name,    type: String
end

