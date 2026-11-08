class ServerAuthToken
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  store_in collection: 'server_auth_tokens'

  field :s, as: :server,       type: String
  field :d, as: :token_digest, type: String

  validates_presence_of :server
  validates_presence_of :token_digest
  validates_uniqueness_of :server
  validates_uniqueness_of :token_digest
end
