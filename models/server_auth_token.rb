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

  # The validations above are check-then-write, so they cannot guarantee one row
  # per server under concurrent issuance. These indexes are created lazily by
  # +issue!+ because the web process (not the Sidekiq worker) is the only writer.
  def self.ensure_indexes!
    return if @indexes_ensured

    collection.indexes.create_one({s: 1}, unique: true, name: "unique_server_auth_token_server")
    collection.indexes.create_one({d: 1}, unique: true, name: "unique_server_auth_token_digest")
    @indexes_ensured = true
  end

  # Atomically replaces the digest for +server+, so a reissue can never leave the
  # previous token valid. Retries once if a concurrent insert wins the upsert.
  def self.issue!(server, token_digest)
    ensure_indexes!

    now = Time.now.utc
    write = {
      "$set" => {d: token_digest, u_at: now},
      "$setOnInsert" => {c_at: now}
    }

    attempts = 0
    begin
      attempts += 1
      collection.find_one_and_update({s: server}, write, upsert: true, return_document: :after)
    rescue Mongo::Error::OperationFailure => e
      raise unless e.code == 11_000 && attempts < 2

      retry
    end
  end
end
