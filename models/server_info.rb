class ServerInfo
  include Mongoid::Document
  include Mongoid::Timestamps

  store_in collection: "server_infos"

  # The last successfully parsed standard server document for a polled server.
  # The unique index on server is created by DataPoller.ensure_indexes!.
  #
  # `created_at` and `updated_at` are Mongo bookkeeping from
  # Mongoid::Timestamps, not document fields.

  # Not a document field: the configured polling target name from
  # data/servers.rb. This is TreeStats' identity for the server.
  field :server, type: String

  # Not a document field: the outcome of the poll that wrote this result.
  field :outcome, type: String

  # JSON: population.count
  field :count, type: Integer

  # JSON: population.updated_at, falling back to updated_at when absent
  field :population_updated_at, type: Time

  # JSON: updated_at
  field :document_updated_at, type: Time

  # JSON: name. Remote metadata, not the TreeStats server identity.
  field :name, type: String

  # JSON: emulator.name
  field :emulator_name, type: String

  # JSON: emulator.version (legacy; not part of the current v1 schema)
  field :emulator_version, type: String

  # JSON: emulator.server_version
  field :emulator_server_version, type: String

  # JSON: emulator.database_version
  field :emulator_database_version, type: String

  # JSON: emulator.dat_iterations
  field :emulator_dat_iterations, type: Hash

  # JSON: schema
  field :schema_url, type: String

  # JSON: version
  field :document_version, type: Integer
end
