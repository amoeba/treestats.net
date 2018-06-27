class PlayerCount
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short

  def serializable_hash(options)
    original_hash = super(options)
    Hash[original_hash.map {|k, v| [self.aliased_fields.invert[k] || k , v] }]
  end

  field :s, as: :server, type: String
  field :c, as: :count,  type: Integer
end
