require "./app"

require "sidekiq/web"
require "sidekiq-cron"
Sidekiq::Web.use Rack::Session::Cookie,
  secret: ENV.fetch("SESSION_SECRET", "dev-only-secret-change-in-production"),
  same_site: true,
  max_age: 86400
Sidekiq.configure_client do |config|
  config.redis = {url: ENV["REDIS_URL"] || "redis://localhost:6379"}
end

map TreeStats.assets_prefix do
  run TreeStats.sprockets
end

map "/sidekiq" do
  if ENV["SIDEKIQ_WEB_PASSWORD"]
    Sidekiq::Web.use Rack::Auth::Basic, "Sidekiq" do |username, password|
      username == ENV.fetch("SIDEKIQ_WEB_USERNAME", "admin") &&
        password == ENV["SIDEKIQ_WEB_PASSWORD"]
    end
  elsif ENV["RACK_ENV"] != "development" && ENV["RACK_ENV"] != "test"
    run proc { [403, {}, []] }
    next
  end
  run Sidekiq::Web
end

map "/" do
  run TreeStats
end
