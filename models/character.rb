class Character
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  # serializable_hash
  # Override default serializable_hash
  #
  # Gets normal serializable_hash and maps the
  # aliased field names back to the full field names

  def serializable_hash(options)
    original_hash = super(options)
    Hash[original_hash.map {|k, v| [self.aliased_fields.invert[k] || k , v] }]
  end


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

  field :acc,  as: :account_name,      type: String

  after_save do |document|
    self_race = RaceHelper::get_race_name(self.race.to_i)
    self_gender = GenderHelper::get_gender_name(self.gender.to_i)
    
    # Monarch
    if self.monarch
      monarch = Character.find_or_create_by(name: self.monarch['name'], server: self.server)

      monarch_race = RaceHelper::get_race_name(self.monarch["race"].to_i)
      monarch_gender = GenderHelper::get_gender_name(self.monarch["gender"].to_i)
      
      monarch.set(race: monarch_race, gender: monarch_gender)
      
      if self.allegiance_name
        monarch.set(allegiance_name: self.allegiance_name)
      end
    end

    # Patron
    if self.patron
      patron = Character.find_or_create_by(name: self.patron['name'], server: self.server)
      
      # Convert gender names to IDs
      # The `self` object has race and gender as names and not IDs
      # but race and gender are IDs everywhere else
      
      patron_race = RaceHelper::get_race_name(self.patron["race"].to_i)
      patron_gender = GenderHelper::get_gender_name(self.patron["gender"].to_i)
      
      patron.set(gender: patron_gender, race: patron_race)

      vassals = patron.vassals

      vassal_record = {
          'name' => self.name,
          'rank' => self.rank,
          'race' => self_race,
          'gender' => self_gender
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
        monarch_info = self.monarch
        monarch_info["race"] = RaceHelper::get_race_name(monarch_info["race"].to_i)
        monarch_info["gender"] = GenderHelper::get_gender_name(monarch_info["gender"].to_i)
        
        patron.set(monarch: monarch_info)
      end

      if self.allegiance_name
        patron.set(allegiance_name: self.allegiance_name)
      end
    end

    # Vassals
    if self.vassals
      self.vassals.each do |v|
        vassal = Character.find_or_create_by(name: v['name'], server: self.server)
        
        vassal_info = v
        vassal_info["race"] = RaceHelper::get_race_name(v["race"].to_i)
        vassal_info["gender"] = GenderHelper::get_gender_name(v["gender"].to_i)
        
        vassal.set(vassal_info)

        vassal.set(patron: {
          'name' => self.name,
          'rank' => self.rank,
          'race' => self_race,
          'gender' => self_gender
          })

        if self.monarch
          monarch_info = self.monarch
          monarch_info["race"] = RaceHelper::get_race_name(monarch_info["race"].to_i)
          monarch_info["gender"] = GenderHelper::get_gender_name(monarch_info["gender"].to_i)
        
          vassal.set(monarch: monarch_info)
        end

        if self.allegiance_name
          vassal.set(allegiance_name: self.allegiance_name)
        end
      end
    end
  end
end
