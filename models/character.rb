class Character
  include Mongoid::Document
  include Mongoid::Timestamps::Short
  
  field :n,   as: :name,            type: String
  field :s,   as: :server,          type: String
  field :r,   as: :race,            type: String
  field :g,   as: :gender,          type: String
  field :l,   as: :level,           type: Integer
  field :rn,  as: :rank,            type: Integer
  field :t,   as: :title,           type: String
  field :f,   as: :followers,       type: Integer
  field :d,   as: :deaths,          type: Integer
  field :b,   as: :birth,           type: DateTime
  field :tx,  as: :total_xp,        type: Integer
  field :u,   as: :unassigned_xp,   type: Integer
  field :sc,  as: :skill_credits,   type: Integer
  
  field :a,   as: :attribs,         type: Hash
  field :vi,  as: :vitals,          type: Hash
  field :sk,  as: :skills,          type: Hash
  
  field :an,  as: :allegiance_name, type: String
  field :m,   as: :monarch,         type: Hash
  field :p,   as: :patron,          type: Hash
  field :v,   as: :vassals,         type: Array
  
  field :ve,  as: :version,         type: Integer
  
  field :tc,  as: :current_title,   type: Integer
  field :ti,  as: :titles,          type: Array
end