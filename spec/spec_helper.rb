# spec_helper.rb

ENV['RACK_ENV'] = 'test'

require 'bundler'
Bundler.require :default, :test

# Rack::MockRequest.env_for calls StringIO#set_encoding on the raw input string,
# which mutates a literal string and triggers Ruby 3.4 frozen-string warnings.
# Dup-ing the string before rack touches it prevents the mutation.
module Rack
  class MockRequest
    class << self
      prepend(Module.new {
        def env_for(uri = "", opts = {})
          opts = opts.merge(input: opts[:input].dup) if opts[:input].is_a?(String)
          super
        end
      })
    end
  end
end

require 'minitest/autorun'
require 'minitest/spec'

# Load the app
require_relative '../app'
Mongo::Logger.logger.level = ::Logger::FATAL

# Create a custom class inheriting from MiniTest::Spec for your unit tests
class UnitTest < Minitest::Spec
  # Any test that ends with 'Unit|Spec|Model' is a `UnitTest`
  register_spec_type(/(Unit|Spec|Model)$/, self)

  # Any test that is a class rather than a string is also a `UnitTest`
  register_spec_type(self) do |desc|
    true if desc.is_a?(Class)
  end
end

# Based on https://gist.github.com/jazzytomato/79bb6ff516d93486df4e14169f4426af
def with_env(env)
  old_env = ENV.to_hash
  ENV.update env

  begin
    yield
  ensure
    ENV.replace old_env
  end
end

def without_env(key)
  old_env = ENV.to_hash
  ENV.delete key

  begin
    yield
  ensure
    ENV.replace old_env
  end
end
