# spec/story_helper.rb

require_relative "spec_helper"

require 'rack/test'

class StoryTest < UnitTest
  include Rack::Test::Methods

  register_spec_type(/Story$/, self)

  def app
    App
  end
end
