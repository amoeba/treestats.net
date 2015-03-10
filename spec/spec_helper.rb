# spec_helper.rb

ENV['RACK_ENV'] = 'test'

require 'bundler'
Bundler.require :default, :test

require 'minitest/autorun'
require 'minitest/spec'

# Load the app
require_relative '../app'

# Load helpers
require_relative 'support/unit_helpers.rb'

# Create a custom class inheriting from MiniTest::Spec for your unit tests
class UnitTest < MiniTest::Spec
  include UnitHelpers

  # Any test that ends with 'Unit|Spec|Model' is a `UnitTest`
  register_spec_type(/(Unit|Spec|Model)$/, self)

  # Any test that is a class rather than a string is also a `UnitTest`
  register_spec_type(self) do |desc|
    true if desc.is_a?(Class)
  end
end