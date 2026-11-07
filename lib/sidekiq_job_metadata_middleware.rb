# frozen_string_literal: true

# Preserve Sidekiq's original enqueue time for cron dispatchers, so a delayed
# dispatcher cannot turn an old schedule tick into a fresh poll slot.
class SidekiqJobMetadataMiddleware
  def call(_worker, job_hash, _queue)
    Thread.current[:sidekiq_enqueued_at] = job_hash["enqueued_at"]&.to_i
    yield
  ensure
    Thread.current[:sidekiq_enqueued_at] = nil
  end
end
