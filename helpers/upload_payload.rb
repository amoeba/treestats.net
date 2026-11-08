# Normalizes an upload body before it reaches the database. Unknown top-level
# keys are ignored so clients can send extra metadata such as Mongo's `_id`
# without failing. Fields that drive queries must be strings so a JSON object
# can never be interpreted as a Mongo operator.
#
# Field groups live on Character (UPLOAD_*_FIELDS); this module only enforces the
# shape of each group.
module UploadPayload
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

  Result = Struct.new(:payload, :population, keyword_init: true)

  def self.sanitize(raw)
    payload = {}
    population = nil

    raw.each do |key, value|
      case key
      when *Character::UPLOAD_REQUIRED_FIELDS
        # An empty name is allowed so the level-1 message is preserved.
        payload[key] = require_string(key, value, allow_empty: key == "name")
      when "server_population"
        population = population_value(value)
      else
        next unless Character::UPLOAD_FIELDS.include?(key)

        # A JSON null clears the field, matching how an omitted value behaves.
        payload[key] = value.nil? ? nil : coerce(key, value)
      end
    end

    raise Invalid.new("server", "is required") unless payload.key?("server")
    raise Invalid.new("name", "is required") unless payload.key?("name")

    Result.new(payload: payload, population: population)
  end

  def self.coerce(key, value)
    case key
    when *Character::UPLOAD_SCALAR_FIELDS
      scalar(key, value)
    when *Character::UPLOAD_INTEGER_FIELDS
      integer(key, value)
    when *Character::UPLOAD_OBJECT_FIELDS
      hash(key, value)
    when *Character::UPLOAD_PERSON_FIELDS
      person(key, value)
    when *Character::UPLOAD_VASSAL_FIELDS
      vassals(value)
    when *Character::UPLOAD_ARRAY_FIELDS
      array(key, value)
    else
      raise Invalid.new(key, "is not an uploadable field")
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

  # Population samples are best effort: a bad value must not drop the
  # character upload. Only a positive integer becomes a PlayerCount.
  def self.population_value(value)
    count = case value
            when Integer then value
            when String then Integer(value, 10, exception: false)
            end

    count if count.is_a?(Integer) && count.positive?
  end
  private_class_method :population_value
end
