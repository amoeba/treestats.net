# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.4.1'

gem 'json'
gem 'puma'
gem 'puma_worker_killer'
gem 'rack'
gem 'rake'
gem 'sinatra'
gem 'sinatra-cross_origin'
gem 'sinatra-redis'

gem 'mongoid'
gem 'redis'

gem 'clockwork'
gem 'resque'

gem 'haml'
gem 'sassc'
gem 'sprockets', '~>4.0.2'
gem 'sprockets-helpers'
gem 'uglifier'

group :development do
  gem 'nokogiri'
  gem 'pry'
  gem 'standardrb'
end

group :production do
  gem 'newrelic_rpm'
  gem 'sentry-resque'
  gem 'sentry-ruby'
end

group :test do
  gem 'minitest'
  gem 'rack-test'
end
