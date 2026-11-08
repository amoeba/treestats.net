require_relative "../spec_helper"

# The upload allowlist lives on Character (UPLOAD_*_FIELDS). These tests make
# adding a model field fail loudly until it is classified, and keep each group
# matching the field's declared Mongoid type.
describe "Character upload fields" do
  # Mongoid bookkeeping, not part of the upload surface.
  def non_upload_fields
    %w[_id created_at updated_at]
  end

  def upload_groups
    [
      Character::UPLOAD_REQUIRED_FIELDS,
      Character::UPLOAD_SCALAR_FIELDS,
      Character::UPLOAD_INTEGER_FIELDS,
      Character::UPLOAD_OBJECT_FIELDS,
      Character::UPLOAD_PERSON_FIELDS,
      Character::UPLOAD_ARRAY_FIELDS,
      Character::UPLOAD_VASSAL_FIELDS
    ]
  end

  def field_for(name)
    db_name = Character.aliased_fields[name] || name
    Character.fields.fetch(db_name)
  end

  def declared_fields
    Character.fields.values.map { |field| (field.options[:as] || field.name).to_s }
  end

  it "classifies every model field" do
    classified = Character::UPLOAD_FIELDS + Character::UPLOAD_INTERNAL_FIELDS + non_upload_fields

    assert_empty declared_fields - classified,
      "unclassified field(s) #{declared_fields - classified}: add to a Character::UPLOAD_* group or UPLOAD_INTERNAL_FIELDS"
    assert_empty classified - declared_fields,
      "stale name(s) #{classified - declared_fields}: remove from Character::UPLOAD_*"
  end

  it "puts each field in exactly one group" do
    grouped = upload_groups.flatten + Character::UPLOAD_INTERNAL_FIELDS
    duplicates = grouped.group_by(&:itself).select { |_name, occurrences| occurrences.length > 1 }.keys

    assert_empty duplicates
  end

  it "keeps internal fields out of uploads" do
    Character::UPLOAD_INTERNAL_FIELDS.each do |name|
      refute_includes Character::UPLOAD_FIELDS, name
    end
  end

  it "matches each group to the field's declared type" do
    {
      Character::UPLOAD_REQUIRED_FIELDS => [String],
      Character::UPLOAD_SCALAR_FIELDS => [String, DateTime],
      Character::UPLOAD_INTEGER_FIELDS => [Integer],
      Character::UPLOAD_OBJECT_FIELDS => [Hash],
      Character::UPLOAD_PERSON_FIELDS => [Hash],
      Character::UPLOAD_ARRAY_FIELDS => [Array],
      Character::UPLOAD_VASSAL_FIELDS => [Array]
    }.each do |fields, expected_types|
      fields.each do |name|
        assert_includes expected_types, field_for(name).type,
          "#{name} is in a group expecting #{expected_types.inspect} but is declared as #{field_for(name).type}"
      end
    end
  end
end
