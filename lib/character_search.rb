class CharacterSearch

  ALLOWED_FIELDS = [ "name", "level" ]

  def initialize(input)
    @input = input
  end

  def to_h
    filters.map { |f| f.split(":") }.to_h.transform_keys(&:to_sym)
  end

  def filters
    name_filters + other_filters
  end

  private

  def name_filters
    return [] if name.empty?

    ["name:#{name}"].compact
  end

  def name
    words.reject { |word| word.include?(":") }.join(" ")
  end

  def words
    @input.split
  end

  def other_filters
    words
      .select { |word| word.include?(":") }
      .select { |filter| valid?(filter) }
  end

  def valid?(filter)
    pair = filter.split(":")
    pair.count == 2 && ALLOWED_FIELDS.include?(pair.first)
  end

end
