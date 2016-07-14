# spec/story_helper.rb

require_relative "spec_helper"
require 'rack/test'

class StoryTest < UnitTest
  include Rack::Test::Methods
  include Sinatra::RedisHelper

  register_spec_type(/Story$/, self)

  def app
    TreeStats
  end

  def redis
    Sinatra::RedisHelper.redis
  end
end
