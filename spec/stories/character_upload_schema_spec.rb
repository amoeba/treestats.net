require_relative "../story_helper"

describe "CharacterUploadSchemaStory" do
  def schema_path
    File.expand_path("../../public/schemas/character/v2/schema.json", __dir__)
  end

  def full_payload_path
    File.expand_path("../../util/full/full.json", __dir__)
  end

  def vassal_payload_path
    File.expand_path("../../util/multi/characters/magus_recent.json", __dir__)
  end

  def docs_path
    File.expand_path("../../docs/direct-upload.md", __dir__)
  end

  def schema
    @schema ||= JSON.parse(File.read(schema_path))
  end

  def full_payload
    @full_payload ||= JSON.parse(File.read(full_payload_path))
  end

  def vassal_payload
    @vassal_payload ||= JSON.parse(File.read(vassal_payload_path))
  end

  def docs_example(name)
    body = File.read(docs_path)[/<!-- example:#{name} -->\s*```json\n(.*?)```/m, 1]
    refute_nil body, "docs are missing the #{name} example"
    JSON.parse(body)
  end

  def fixture_paths
    Dir[File.expand_path("../../util/**/*.{json,txt}", __dir__)].sort
  end

  it "serves the published character upload schema" do
    get "/schemas/character/v2/schema.json"

    assert_equal 200, last_response.status
    assert_equal "application/json", last_response.headers["Content-Type"]
    assert_equal schema, JSON.parse(last_response.body)
  end

  it "describes every field in the canonical full.json payload" do
    assert_empty full_payload.keys - schema.fetch("properties").keys
  end

  it "only describes fields the uploader accepts" do
    uploadable = Character::UPLOAD_FIELDS + %w[server_population]

    assert_empty schema.fetch("properties").keys - uploadable
  end

  it "validates the canonical full.json payload" do
    assert_empty validate(schema, full_payload)
  end

  it "describes vassals and location" do
    assert_equal "array", schema.dig("properties", "vassals", "type")
    assert_equal "string", schema.dig("properties", "location", "type")
  end

  it "validates a payload with vassals and location" do
    payload = vassal_payload.merge("location" => "Holtburg")

    assert_empty validate(schema, payload)
  end

  it "validates the documented upload examples" do
    %w[minimal maximal].each do |name|
      errors = validate(schema, docs_example(name))

      assert_empty errors, "#{name} example does not match the schema: #{errors.join(", ")}"
    end
  end

  it "validates the documented examples against the direct upload schema" do
    %w[minimal maximal].each do |name|
      payload = docs_example(name)

      refute payload.key?("account_name")
      refute payload.key?("server_population")
      assert_empty validate(schema.fetch("$defs").fetch("directUpload"), payload)
      assert_equal payload["name"], UploadPayload.sanitize(payload, source: :direct).payload["name"]
    end
  end

  it "requires names for root race and gender and integer IDs in direct allegiance records" do
    direct_schema = schema.fetch("$defs").fetch("directUpload")
    payload = {
      "name" => "Example",
      "server" => "Example Server",
      "race" => "Sho",
      "gender" => "Female",
      "patron" => {"name" => "Patron", "race" => 3, "gender" => 2}
    }

    assert_empty validate(direct_schema, payload)
    refute_empty validate(direct_schema, payload.merge("race" => 3))
    refute_empty validate(direct_schema, payload.merge("gender" => 2))
    refute_empty validate(direct_schema, payload.merge(
      "patron" => {"name" => "Patron", "race" => "3", "gender" => "2"}
    ))
  end

  it "documents the allegiance race and gender IDs used by uploads" do
    docs = File.read(docs_path)
    race_mapping = docs[/^Race\n\n(.*?)(?=\n\nGender)/m, 1]
    gender_mapping = docs[/^Gender\n\n(.*?)(?=\n\n##)/m, 1]

    expected_races = RaceHelper::RACES.map { |id, name| "- `#{id}` — #{name}" }.join("\n")
    expected_genders = GenderHelper::GENDERS.map { |id, name| "- `#{id}` — #{name}" }.join("\n")

    assert_equal expected_races, race_mapping
    assert_equal expected_genders, gender_mapping
  end

  it "allows plugin account names but rejects them in the direct upload schema" do
    direct_schema = schema.fetch("$defs").fetch("directUpload")
    payload = {"name" => "Example", "server" => "Example Server"}

    assert_empty validate(schema, payload.merge("account_name" => "plugin-account"))
    %w[account_name acc].each do |key|
      ["account", "", nil].each do |value|
        refute_empty validate(direct_schema, payload.merge(key => value))
      end
    end

    [
      {"monarch" => {"name" => "Monarch", "account_name" => "account"}},
      {"patron" => {"name" => "Patron", "acc" => nil}},
      {"vassals" => [{"name" => "Vassal", "account_name" => ""}]},
      {"monarch" => {"name" => "Monarch", "vassals" => [{"name" => "Vassal", "acc" => "account"}]}}
    ].each do |related|
      refute_empty validate(direct_schema, payload.merge(related))
    end
  end

  it "allows ignored population data of any type in the direct upload schema" do
    direct_schema = schema.fetch("$defs").fetch("directUpload")

    [123, "123", 0, -5, "abc", 1.5, nil, true, {}, []].each do |value|
      payload = {"name" => "Example", "server" => "Example Server", "server_population" => value}

      assert_empty validate(direct_schema, payload)
      assert_nil UploadPayload.sanitize(payload, source: :direct).population
    end
  end

  it "accepts the documented upload examples" do
    %w[minimal maximal].each do |name|
      result = UploadPayload.sanitize(docs_example(name), source: :direct)

      assert_equal docs_example(name)["name"], result.payload["name"]
    end
  end

  it "validates the upload fixtures" do
    fixture_paths.each do |path|
      payload = JSON.parse(File.read(path))
      next unless payload.is_a?(Hash)

      errors = validate(schema, payload)

      assert_empty errors, "#{File.basename(path)} does not match the schema: #{errors.join(", ")}"
    end
  end

  it "accepts numeric strings for integer fields" do
    payload = full_payload.merge("level" => "5", "server_population" => "138")

    assert_empty validate(schema, payload)
    assert_equal 5, UploadPayload.sanitize(payload, source: :plugin).payload["level"]
  end

  it "accepts the canonical full.json payload" do
    result = UploadPayload.sanitize(full_payload, source: :plugin)

    assert_equal full_payload["name"], result.payload["name"]
    assert_equal full_payload["server"], result.payload["server"]
    assert_equal full_payload["server_population"], result.population
  end

  private

  # Minimal validator for the JSON Schema keywords this schema uses. Keeping
  # the suite dependency-free means the canonical payload is still checked
  # against the published schema on every run.
  def validate(node, value, path = "$")
    return [] if node == true
    return ["#{path}: forbidden value"] if node == false

    node = resolve_ref(node, schema)

    errors = Array(node["allOf"]).flat_map { |child| validate(child, value, path) }
    errors.concat(validate_type(node, value, path))
    errors.concat(validate_value(node, value, path))

    case value
    when Hash
      errors.concat(validate_object(node, value, path))
    when Array
      errors.concat(validate_array(node, value, path))
    end

    errors
  end

  def resolve_ref(node, root)
    ref = node["$ref"]
    return root if ref == "#"
    return node unless ref&.start_with?("#/")

    root.dig(*ref.delete_prefix("#/").split("/"))
  end

  def validate_type(node, value, path)
    types = Array(node["type"])
    return [] if types.empty? || types.any? { |type| matches_type?(type, value) }

    ["#{path}: expected #{types.join(" or ")}"]
  end

  def matches_type?(type, value)
    case type
    when "object" then value.is_a?(Hash)
    when "array" then value.is_a?(Array)
    when "string" then value.is_a?(String)
    when "integer" then value.is_a?(Integer)
    when "number" then value.is_a?(Numeric)
    when "boolean" then value == true || value == false
    when "null" then value.nil?
    else true
    end
  end

  def validate_value(node, value, path)
    errors = []

    if node.key?("const") && value != node["const"]
      errors << "#{path}: expected #{node["const"].inspect}"
    end

    if node.key?("enum") && !node["enum"].include?(value)
      errors << "#{path}: expected one of #{node["enum"].inspect}"
    end

    if value.is_a?(String) && node["pattern"] && !Regexp.new(node["pattern"]).match?(value)
      errors << "#{path}: does not match #{node["pattern"]}"
    end

    if value.is_a?(String) && node.key?("minLength") && value.length < node["minLength"]
      errors << "#{path}: must have at least #{node["minLength"]} characters"
    end

    if value.is_a?(Numeric) && node.key?("minimum") && value < node["minimum"]
      errors << "#{path}: must be at least #{node["minimum"]}"
    end

    errors
  end

  def validate_object(node, value, path)
    errors = []

    Array(node["required"]).each do |key|
      errors << "#{path}: missing #{key.inspect}" unless value.key?(key)
    end

    properties = node["properties"] || {}
    patterns = node["patternProperties"] || {}
    additional = node["additionalProperties"]

    value.each do |key, child|
      child_path = "#{path}.#{key}"

      if properties.key?(key)
        errors.concat(validate(properties[key], child, child_path))
      elsif (_pattern, subschema = patterns.find { |candidate, _| Regexp.new(candidate).match?(key) })
        errors.concat(validate(subschema, child, child_path))
      elsif additional == false
        errors << "#{child_path}: unexpected key"
      elsif additional.is_a?(Hash)
        errors.concat(validate(additional, child, child_path))
      end
    end

    errors
  end

  def validate_array(node, value, path)
    items = node["items"]
    return [] unless items

    value.each_with_index.flat_map do |child, index|
      validate(items, child, "#{path}[#{index}]")
    end
  end
end
