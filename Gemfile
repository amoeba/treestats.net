# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.4.7'

gem 'json'
gem 'oj'
gem 'puma'
gem 'puma_worker_killer'
gem 'rack'
gem "ostruct", "~> 0.6.1"
gem 'rake'
gem 'sinatra'
gem 'sinatra-cross_origin'
gem 'sinatra-redis'

gem 'mongoid'
gem 'redis'

gem 'clockwork'
gem 'resque'

gem 'sidekiq'
gem 'sidekiq-cron'
gem 'connection_pool', '~> 2.4'

gem 'haml'

group :development do
  gem 'nokogiri'
  gem 'pry'
  gem 'standardrb'
  gem 'foreman'
end

group :production do
  gem 'newrelic_rpm'
  gem 'sentry-resque'
  gem 'sentry-ruby'
  gem 'sentry-sidekiq'
end

group :test do
  gem 'minitest'
  gem 'rack-test'
end
