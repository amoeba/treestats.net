source "https://rubygems.org"
ruby "3.2.0"

gem "rake"
gem "json"
gem "rack"
gem "puma"
gem "puma_worker_killer"
gem "sinatra"
gem "sinatra-redis"
gem "sinatra-cross_origin"

gem "mongoid"
gem "redis"

gem "clockwork"
gem "resque"

gem "sprockets", "~>4.0.2"
gem "sprockets-helpers"
gem "haml"
gem "sassc"
gem "uglifier"

group :development do
  gem "pry"
  gem "nokogiri"
  gem "standard"
end

group :production do
  gem "sentry-ruby"
  gem "newrelic_rpm"
end

group :test do
  gem "minitest"
  gem "rack-test"
end

gem "ruby-lsp", "~> 0.3.7", :group => :development
