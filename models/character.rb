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

  FILTERED_FIELDS = [ "id", "ip_address", "upload_source" ]

  # The most recent upload's source. nil means the Decal plugin, which is the
  # historical default and the shape of every document written before this field
  # existed.
  SERVER_SOURCE = "s"

  def uploaded_by_server?
    upload_source == SERVER_SOURCE
  end

  def to_json
    JSON.pretty_generate(serializable_hash({}).tap { |h| Character::FILTERED_FIELDS.each { |f| h.delete(f) }})
  end

  default_scope -> { where({
    'ar' => false,
    'n' => { '$regex' => /^[^\+]+/}
  })}



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
  field :ip,  as: :ip_address,        type: String
  field :us,  as: :upload_source,     type: String

  field :ar,  as: :archived,          type: Boolean, default: -> { false }

  field :lo,  as: :location,          type: String

  # Indexes used by the /stats page counts (and cheap enough to keep around
  # for everything else). The archived partial index is tiny; n and s are
  # full indexes. Call Character.ensure_indexes! once per environment
  # (rake characters:ensure_indexes) to build them.
  index({ s: 1 })
  index({ n: 1 })
  index({ ar: 1 }, { partial_filter_expression: { ar: true } })

  def self.ensure_indexes!
    create_indexes
  end

  # Upload payload groups, by the shape each field expects. UploadPayload
  # validates according to these groups; anything not listed is never set from
  # a payload. Every model field must appear in exactly one group or in
  # UPLOAD_INTERNAL_FIELDS - spec/unit/character_upload_fields_spec.rb enforces
  # that, and that each group matches the field's declared type.
  UPLOAD_REQUIRED_FIELDS = %w[name server].freeze
  UPLOAD_SCALAR_FIELDS = %w[race gender birth allegiance_name account_name location].freeze
  UPLOAD_INTEGER_FIELDS = %w[
    level rank followers deaths total_xp unassigned_xp skill_credits
    luminance_earned luminance_total version current_title
  ].freeze
  UPLOAD_OBJECT_FIELDS = %w[properties attribs vitals skills].freeze
  # Objects whose `name` is used to find or create another character.
  UPLOAD_PERSON_FIELDS = %w[monarch patron].freeze
  UPLOAD_ARRAY_FIELDS = %w[titles].freeze
  # Array of objects whose `name` is used to find or create another character.
  UPLOAD_VASSAL_FIELDS = %w[vassals].freeze
  # Server-managed: never accepted from a payload.
  UPLOAD_INTERNAL_FIELDS = %w[ip_address archived upload_source].freeze

  UPLOAD_FIELDS = (
    UPLOAD_REQUIRED_FIELDS + UPLOAD_SCALAR_FIELDS + UPLOAD_INTEGER_FIELDS +
    UPLOAD_OBJECT_FIELDS + UPLOAD_PERSON_FIELDS + UPLOAD_ARRAY_FIELDS +
    UPLOAD_VASSAL_FIELDS
  ).freeze

  after_save do |document|
    self_race = RaceHelper::get_race_name(self.race.to_i)
    self_gender = GenderHelper::get_gender_name(self.gender.to_i)

    # Monarch
    if self.monarch
      monarch = Character.unscoped.find_or_create_by(name: self.monarch['name'], server: self.server)

      monarch_info = self.monarch

      monarch_info["race"] = RaceHelper::get_race_name(monarch_info["race"].to_i)
      monarch_info["gender"] = GenderHelper::get_gender_name(monarch_info["gender"].to_i)

      monarch.set(monarch_info)

      if self.allegiance_name
        monarch.set(allegiance_name: self.allegiance_name)
      end
    end

    # Patron
    if self.patron
      patron = Character.unscoped.find_or_create_by(name: self.patron['name'], server: self.server)

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

      # Remove any old patrons
      patrons = Character.where(server: self.server, vassals: { "$elemMatch" =>  { 'name' => self.name} })

      patrons.each do |p|
        if p['name'] != self.patron['name'] then
          p.set(vassals: p.vassals.select! { |v| self.name != v['name']})
        end
      end

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
        vassal = Character.unscoped.find_or_create_by(name: v['name'], server: self.server)

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
