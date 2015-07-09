# spec/story_helper.rb

require_relative "spec_helper"
require_relative "support/story_helpers.rb"

require 'rack/test'

class StoryTest < UnitTest
  include Rack::Test::Methods
  include StoryHelpers

  register_spec_type(/Story$/, self)

  def app
    App
  end
end
