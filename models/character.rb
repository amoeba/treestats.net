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

  def stub?
    self.attribs.nil?
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

  field :acc, as: :account_name,      type: String

  # Skip callbacks when a stub
  skip_callback(:save, :after, :update_other_characters, if: -> { self.stub? })

  after_save :update_related_characters

  def update_related_characters
    update_monarch
    update_patron
    update_vassals
    update_allegiance
  end

  def update_monarch
    return if self.monarch.nil?

    monarch = Character.find_or_create_by(name: self.monarch['name'], server: self.server)

    monarch_info = self.monarch
    monarch_info["race"] = RaceHelper::get_race_name(monarch_info["race"])
    monarch_info["gender"] = GenderHelper::get_gender_name(monarch_info["gender"])
    monarch.set(monarch_info)

    monarch.set(allegiance_name: self.allegiance_name)
  end

  def update_patron
    if self.patron
      patron = Character.find_or_create_by(name: self.patron['name'], server: self.server)

      patron_race = RaceHelper::get_race_name(self.patron["race"])
      patron_gender = GenderHelper::get_gender_name(self.patron["gender"])
      patron.set(gender: patron_gender, race: patron_race)

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

      # Remove any old patrons
      patrons = Character.where(server: self.server, vassals: { "$elemMatch" =>  { 'name' => self.name} })

      patrons.each do |p|
        continue if p['name'] == self.patron['name']

        p.set(vassals: p.vassals.select! { |v| self.name != v['name']})
      end

      patron.set(allegiance_name: self.allegiance_name)
    else
      # Remove this character as a vassal from any characters
      # Find all characters who have this character as a vassal
      patrons = Character.where(server: self.server, vassals: { "$elemMatch" =>  { 'name' => self.name} })

      patrons.each do |p|
        # Skip if the current character is not a vassal
        continue if p.vassals.length == 0 or not p.vassals.detect { |v| self.name == v['name'] }

        # Remove the character as a vassal and update the patron
        p.set(vassals: p.vassals.select! { |v| self.name != v['name']})
      end
    end
  end

  def update_vassals
    if self.vassals
      self.vassals.each do |v|
        vassal = Character.find_or_create_by(name: v['name'], server: self.server)

        vassal_info = v
        vassal_info["race"] = RaceHelper::get_race_name(v["race"])
        vassal_info["gender"] = GenderHelper::get_gender_name(v["gender"])
        vassal.set(vassal_info)

        # Update vassal's patron info
        vassal.set(patron: {
          'name' => self.name,
          'rank' => self.rank,
          'race' => RaceHelper::get_race_id(self.race),
          'gender' => GenderHelper::get_gender_id(self.gender)
        })

        if self.monarch
          vassal.set(monarch: self.monarch)
        end

        if self.allegiance_name
          vassal.set(allegiance_name: self.allegiance_name)
        end
      end
    else
      # If there are no vassals, remove this char as the patron of any
      # vassals that say so
      vassals = Character.where(server: self.server, patron: self.name)

      vassals.each do |vassal|
        vassal.set(patron: nil)
      end
    end
  end

  def update_allegiance
    return if self.allegiance_name.nil?

    Allegiance.find_or_create_by(server: self.server, name: self.allegiance_name)
  end
end
