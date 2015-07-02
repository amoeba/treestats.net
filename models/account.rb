class Account
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  validates_presence_of :name
  validates_presence_of :password

  field :n,   as: :name,        type: String
  field :p,   as: :password,    type: String
end
