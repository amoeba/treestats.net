class ServerInfo
  include Mongoid::Document

  store_in collection: "server_infos"

  # The last successfully parsed standard server document for a polled server.
  # The unique index on server is created by DataPoller.ensure_indexes!.
  field :server, type: String
  field :fetched_at, type: Time
  field :outcome, type: String
  field :count, type: Integer
  field :measured_at, type: Time
  field :document_updated_at, type: Time
  field :name, type: String
  field :emulator_name, type: String
  field :emulator_version, type: String
  field :schema_url, type: String
  field :document_version, type: Integer
end
