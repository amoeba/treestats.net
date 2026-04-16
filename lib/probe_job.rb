# frozen_string_literal: true

require "sidekiq"

class ProbeJob
  include Sidekiq::Worker

  def perform
    logger.info "Sidekiq cron probe ran successfully"
  end
end
