require 'bundler'

Bundler.require(:default, ENV["RACK_ENV"])

require 'tilt/haml'
require './app'

run Sinatra::Application
