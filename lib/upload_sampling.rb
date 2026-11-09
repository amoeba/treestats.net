module UploadSampling
  RATE = begin
    value = Float(ENV.fetch("UPLOAD_SAMPLE_RATE", "0"))
    raise ArgumentError unless value.finite? && value.between?(0.0, 1.0)
    value
  rescue ArgumentError
    raise ArgumentError, "UPLOAD_SAMPLE_RATE must be a number between 0 and 1"
  end

  FIELDS = %w[
    name server race gender level rank followers deaths birth total_xp unassigned_xp
    skill_credits luminance_earned luminance_total version current_title allegiance_name
    account_name location server_population attribs vitals skills properties monarch patron
    vassals titles
  ].freeze
  NUMERIC_FIELDS = %w[
    level rank followers deaths total_xp unassigned_xp skill_credits luminance_earned
    luminance_total current_title server_population
  ].freeze
  ATTRIBUTES = %w[strength endurance coordination quickness focus self].freeze
  VITALS = %w[health stamina mana].freeze
  TRAINING = %w[Unusable Untrained Trained Specialized].freeze
  LIMIT = 100

  def self.sample(payload)
    return if RATE <= 0 || rand >= RATE

    summarize(payload)
  rescue
    puts "Failed to prepare upload shape sample."
    nil
  end

  def self.capture(summary)
    return unless summary

    Sentry.with_scope do |scope|
      scope.clear_breadcrumbs
      scope.set_user({})
      scope.set_context("upload_shape", summary)
      Sentry.capture_message("Sampled plugin-endpoint character upload")
    end
  rescue
    puts "Failed to capture upload shape sample."
  end

  def self.summarize(payload)
    fields = FIELDS.each_with_object({}) do |field, result|
      next unless payload.key?(field)
      value = payload[field]
      result[field] = {type: value_type(value)}
      result[field][:range] = number_range(value) if NUMERIC_FIELDS.include?(field) && value.is_a?(Numeric)
    end

    summary = {fields: fields}
    if payload.key?("version")
      version = payload["version"]
      summary[:version] = %w[1 2].include?(version.to_s) ? version.to_s : "other"
    end
    if payload["race"].is_a?(String)
      summary[:race] = RaceHelper::RACE_ID.key?(payload["race"]) ? payload["race"] : "other"
    end
    if payload["gender"].is_a?(String)
      summary[:gender] = GenderHelper::GENDER_ID.key?(payload["gender"]) ? payload["gender"] : "other"
    end
    summary[:birth_format] = birth_format(payload["birth"]) if payload["birth"].is_a?(String)
    summary[:attribs] = named_shapes(payload["attribs"], ATTRIBUTES, %w[name base creation])
    summary[:vitals] = named_shapes(payload["vitals"], VITALS, %w[name base])
    summary[:skills] = skill_shapes(payload["skills"])
    summary[:properties] = property_shapes(payload["properties"])
    summary[:titles] = array_shapes(payload["titles"])
    summary[:monarch] = object_shape(payload["monarch"], %w[name race gender rank followers])
    summary[:patron] = object_shape(payload["patron"], %w[name race gender rank])
    summary[:vassals] = vassal_shapes(payload["vassals"])
    summary.compact
  end

  def self.value_type(value)
    case value
    when NilClass then "null"
    when String then "string"
    when Integer then "integer"
    when Float then "number"
    when TrueClass, FalseClass then "boolean"
    when Array then "array"
    when Hash then "object"
    else "other"
    end
  end
  private_class_method :value_type

  def self.number_range(value)
    return "zero" if value == 0
    return "other" unless value.finite?

    sign = value.negative? ? "negative" : "positive"
    magnitude = value.abs
    return "#{sign}:under_1" if magnitude < 1
    return "#{sign}:1_to_9" if magnitude < 10
    return "#{sign}:10_to_99" if magnitude < 100
    return "#{sign}:100_to_999" if magnitude < 1_000
    return "#{sign}:1000_to_999999" if magnitude < 1_000_000
    "#{sign}:1000000_or_more"
  end
  private_class_method :number_range

  def self.birth_format(value)
    return "us_12h" if /\A\d{1,2}\/\d{1,2}\/\d{4} \d{1,2}:\d{2}:\d{2} (?:AM|PM)\z/.match?(value)
    return "us_24h" if /\A\d{1,2}\/\d{1,2}\/\d{4} \d{1,2}:\d{2}:\d{2}\z/.match?(value)

    "other"
  end
  private_class_method :birth_format

  def self.object_shape(value, fields)
    return unless value.is_a?(Hash)

    fields.each_with_object({}) do |field, result|
      next unless value.key?(field)
      entry = value[field]
      result[field] = {type: value_type(entry)}
      result[field][:range] = number_range(entry) if entry.is_a?(Numeric)
    end
  end
  private_class_method :object_shape

  def self.named_shapes(value, names, fields)
    return unless value.is_a?(Hash)

    result = names.each_with_object({}) do |name, shapes|
      next unless value.key?(name)
      shapes[name] = {type: value_type(value[name]), fields: object_shape(value[name], fields)}.compact
    end
    {known: result, other_keys: (value.keys - names).any?}
  end
  private_class_method :named_shapes

  def self.skill_shapes(value)
    return unless value.is_a?(Hash)

    entries = value.values.take(LIMIT)
    trainings = entries.filter_map do |entry|
      next unless entry.is_a?(Hash) && entry.key?("training")
      TRAINING.include?(entry["training"]) ? entry["training"] : "other"
    end.uniq.sort
    shapes = entries.map do |entry|
      {type: value_type(entry), fields: object_shape(entry, %w[name base training])}.compact
    end.uniq
    {entry_shapes: shapes, training: trainings, truncated: value.size > LIMIT}
  end
  private_class_method :skill_shapes

  def self.property_shapes(value)
    return unless value.is_a?(Hash)

    entries = value.to_a.take(LIMIT)
    {
      key_types: entries.map { |key, _| /\A[0-9]+\z/.match?(key) ? "numeric" : "other" }.uniq.sort,
      value_types: entries.map { |_, entry| value_type(entry) }.uniq.sort,
      truncated: value.size > LIMIT
    }
  end
  private_class_method :property_shapes

  def self.array_shapes(value)
    return unless value.is_a?(Array)

    {item_types: value.take(LIMIT).map { |entry| value_type(entry) }.uniq.sort, truncated: value.size > LIMIT}
  end
  private_class_method :array_shapes

  def self.vassal_shapes(value)
    return unless value.is_a?(Array)

    entries = value.take(LIMIT)
    {
      entry_shapes: entries.map { |entry|
        {type: value_type(entry), fields: object_shape(entry, %w[name race gender rank])}.compact
      }.uniq,
      truncated: value.size > LIMIT
    }
  end
  private_class_method :vassal_shapes
end
