class Character
  include Mongoid::Document
  include Mongoid::Timestamps::Short
  
  validates_presence_of :name
  validates_presence_of :server
  
  field :n,   as: :name,              type: String
  field :s,   as: :server,            type: String
  field :r,   as: :race,              type: String
  field :g,   as: :gender,            type: String
  field :l,   as: :level,             type: Integer
  field :rn,  as: :rank,              type: Integer
  field :f,   as: :followers,         type: Integer
  field :d,   as: :deaths,            type: Integer
  field :b,   as: :birth,             type: DateTime
  field :tx,  as: :total_xp,          type: Integer
  field :u,   as: :unassigned_xp,     type: Integer
  field :sc,  as: :skill_credits,     type: Integer

  field :lx,  as: :luminance_earned,  type: Integer
  field :lt,  as: :luminance_total,   type: Integer    

  field :pr,  as: :properties,        type: Hash
  
  field :a,   as: :attribs,           type: Hash
  field :vi,  as: :vitals,            type: Hash
  field :sk,  as: :skills,            type: Hash

  field :an,  as: :allegiance_name,   type: String
  field :m,   as: :monarch,           type: Hash
  field :p,   as: :patron,            type: Hash
  field :v,   as: :vassals,           type: Array

  field :ve,  as: :version,           type: Integer

  field :tc,  as: :current_title,     type: Integer
  field :ti,  as: :titles,            type: Array
  
  after_save do |document|
    # Monarch
    if self.monarch
      monarch = Character.find_or_create_by(name: self.monarch['name'], server: self.server)
      
      if self.allegiance_name
        monarch.set(allegiance_name: self.allegiance_name)
      end
    end
    
    # Patron
    if self.patron
      patron = Character.find_or_create_by(name: self.patron['name'], server: self.server)
      
      patron.set(self.patron)
      
      vassals = patron.vassals
      
      vassal_record = {
          'name' => self.name,
          'rank' => self.rank,
          'race' => self.race,
          'gender' => self.gender
      }
      
      v_i = vassals && vassals.find_index { |v| v['name'] == self.name }
      
      if(v_i) # Detected
        vassals[v_i] = vassal_record
      else
        vassals ||= []
        vassals.push(vassal_record)
      end
      
      patron.set(vassals: vassals)
      
      if self.monarch
        patron.set(monarch: self.monarch)  
      end
      
      if self.allegiance_name
        patron.set(allegiance_name: self.allegiance_name)
      end
    end
    
    # Vassals
    if self.vassals
      self.vassals.each do |v|
        vassal = Character.find_or_create_by(name: v['name'], server: self.server)
        
        vassal.set(v)

        vassal.set(patron: { 
          'name' => self.name,
          'rank' => self.rank,
          'race' => self.race,
          'gender' => self.gender
          })
        
        if self.monarch
          vassal.set(monarch: self.monarch)  
        end
      
        if self.allegiance_name
          vassal.set(allegiance_name: self.allegiance_name)
        end
      end
    end
  end
end