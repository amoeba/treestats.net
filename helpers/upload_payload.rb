# Normalizes an upload body before it reaches the database. Unknown top-level
# keys are ignored (and reported back) so clients can send extra metadata such
# as Mongo's `_id` without failing. Fields that drive queries must be strings so
# a JSON object can never be interpreted as a Mongo operator.
module UploadPayload
  SCALAR_FIELDS = %w[
    race gender birth allegiance_name account_name location
  ].freeze
  INTEGER_FIELDS = %w[
    level rank followers deaths total_xp unassigned_xp skill_credits
    luminance_earned luminance_total version current_title
  ].freeze
  HASH_FIELDS = %w[properties attribs vitals skills].freeze
  # These contain a `name` that is used to find or create another character.
  PERSON_FIELDS = %w[monarch patron].freeze
  ARRAY_FIELDS = %w[titles].freeze
  KNOWN_FIELDS = (SCALAR_FIELDS + INTEGER_FIELDS + HASH_FIELDS + PERSON_FIELDS +
    ARRAY_FIELDS + %w[vassals]).freeze

  MAX_POPULATION = 100_000

  class Invalid < StandardError
    attr_reader :field

    def initialize(field, message)
      @field = field
      super(message)
    end

    def to_s
      "#{field} #{super}"
    end
  end

  Result = Struct.new(:payload, :ignored, :population, keyword_init: true)

  def self.sanitize(raw)
    payload = {}
    ignored = []
    population = nil

    raw.each do |key, value|
      case key
      when "server"
        payload[key] = require_string(key, value, allow_empty: false)
      when "name"
        # An empty name is allowed so the level-1 message is preserved.
        payload[key] = require_string(key, value, allow_empty: true)
      when "server_population"
        population = population_value(value) unless value.nil?
      else
        unless KNOWN_FIELDS.include?(key)
          ignored << key
          next
        end

        # A JSON null clears the field, matching how an omitted value behaves.
        payload[key] = value.nil? ? nil : coerce(key, value)
      end
    end

    raise Invalid.new("server", "is required") unless payload.key?("server")
    raise Invalid.new("name", "is required") unless payload.key?("name")

    Result.new(payload: payload, ignored: ignored, population: population)
  end

  # Safe to place in a response header: JSON keys can contain anything.
  def self.ignored_header(keys)
    keys.first(20).map { |key| key.to_s.gsub(/[^A-Za-z0-9_.-]/, "?") }.join(",")[0, 200]
  end

  def self.coerce(key, value)
    if SCALAR_FIELDS.include?(key)
      scalar(key, value)
    elsif INTEGER_FIELDS.include?(key)
      integer(key, value)
    elsif HASH_FIELDS.include?(key)
      hash(key, value)
    elsif PERSON_FIELDS.include?(key)
      person(key, value)
    elsif key == "vassals"
      vassals(value)
    else
      array(key, value)
    end
  end
  private_class_method :coerce

  def self.require_string(field, value, allow_empty:)
    raise Invalid.new(field, "must be a string") unless value.is_a?(String)
    raise Invalid.new(field, "must not be empty") if !allow_empty && value.empty?

    value
  end
  private_class_method :require_string

  def self.scalar(field, value)
    case value
    when String then value
    when Integer, Float then value.to_s
    else raise Invalid.new(field, "must be a string or number")
    end
  end
  private_class_method :scalar

  def self.integer(field, value)
    result = case value
             when Integer then value
             when String then Integer(value, 10, exception: false)
             end
    raise Invalid.new(field, "must be an integer") if result.nil?

    result
  end
  private_class_method :integer

  def self.hash(field, value)
    raise Invalid.new(field, "must be an object") unless value.is_a?(Hash)

    value
  end
  private_class_method :hash

  def self.person(field, value)
    hash(field, value)
    if value.key?("name") && !value["name"].nil? && !value["name"].is_a?(String)
      raise Invalid.new("#{field}.name", "must be a string")
    end

    value
  end
  private_class_method :person

  def self.array(field, value)
    raise Invalid.new(field, "must be an array") unless value.is_a?(Array)

    value
  end
  private_class_method :array

  # Vassal names are used to find or create characters, so drop any entry that
  # is not an object with a string name.
  def self.vassals(value)
    array("vassals", value).select do |vassal|
      vassal.is_a?(Hash) && (vassal["name"].nil? || vassal["name"].is_a?(String))
    end
  end
  private_class_method :vassals

  def self.population_value(value)
    count = case value
            when Integer then value
            when String then Integer(value, 10, exception: false)
            end
    unless count.is_a?(Integer) && count >= 0 && count <= MAX_POPULATION
      raise Invalid.new("server_population", "must be an integer between 0 and #{MAX_POPULATION}")
    end

    count
  end
  private_class_method :population_value
end
