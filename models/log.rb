class Log
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short
  
  field :t, as: :title, type: String
  field :m, as: :message,  type: String
end