require 'bundler'

Bundler.require(:default, ENV["RACK_ENV"])

require './app'

run Sinatra::Application