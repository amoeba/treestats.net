class DataPollState
  include Mongoid::Document

  store_in collection: "data_poll_states"

  field :server, type: String
  field :last_checked_at, type: Time
  field :last_outcome, type: String
  field :error_summary, type: String
  field :last_accepted_updated_at, type: Integer
  field :consecutive_failures, type: Integer, default: 0
  # Lease fields are written by DataPoller::Poll through the raw collection.
  field :last_poll_slot, type: Integer
  field :lease_id, type: String
  field :lease_until, type: Time
end
