class BulkUploadLog
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short

  field :account_id,      type: String
  field :submitted_at,    type: Time
  field :record_count,    type: Integer
  field :content_type,    type: String
  field :started_at,      type: Time
  field :completed_at,    type: Time
  field :duration_ms,     type: Integer
  field :processed_count, type: Integer
  field :skipped_count,   type: Integer
  field :error_count,     type: Integer
  field :status,          type: String, default: "queued"  # queued | processing | completed | failed

  index({ submitted_at: -1 })
end
