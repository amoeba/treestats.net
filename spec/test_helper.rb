# test_helper.rb

require 'bundler/setup'

require 'minitest/autorun'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

require File.expand_path '../../app.rb', __FILE__