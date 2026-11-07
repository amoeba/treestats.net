class PlayerCount
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short

  # Compact internal source codes. An absent source means a plugin upload, so
  # plugin observations store no provenance field at all. Accept the legacy long
  # values on read so pre-enum documents remain usable.
  SOURCE_FIELD = :r
  PLUGIN_SOURCE = "p"
  SERVER_SOURCE = "s"
  SOURCE_NAMES = {
    PLUGIN_SOURCE => "plugin",
    SERVER_SOURCE => "server",
    "plugin" => "plugin",
    "server" => "server"
  }.freeze

  # Keep internal polling metadata out of every public serialization. The legacy
  # document's public keys are the two aliases plus Mongoid timestamps/id.
  def serializable_hash(options)
    original_hash = super(options)
    mapped = Hash[original_hash.map { |k, v| [self.aliased_fields.invert[k] || k, v] }]
    mapped.select { |k, _| %w[_id id server count created_at updated_at].include?(k) }
  end

  field :s, as: :server, type: String
  field :c, as: :count,  type: Integer
  field SOURCE_FIELD, as: :source, type: String

  validates :source, inclusion: {in: SOURCE_NAMES.keys}, allow_nil: true

  def effective_source
    # Fall back to the old `source` key for documents written before the rename.
    SOURCE_NAMES.fetch(source || attributes["source"], "plugin")
  end
end
