class PlayerCount
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short

  # Keep internal polling metadata out of every public serialization. The legacy
  # document's public keys are the two aliases plus Mongoid timestamps/id.
  def serializable_hash(options)
    original_hash = super(options)
    mapped = Hash[original_hash.map { |k, v| [self.aliased_fields.invert[k] || k, v] }]
    mapped.select { |k, _| %w[_id id server count created_at updated_at].include?(k) }
  end

  field :s, as: :server, type: String
  field :c, as: :count,  type: Integer
  field :source, type: String
  field :received_at, type: Time

  def effective_source
    source || "plugin"
  end
end
