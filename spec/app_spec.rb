# app_spec.rb
# Tests general features of the app

require File.expand_path '../test_helper.rb', __FILE__

class MyTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    Treestats::App
  end

  def does_respond
    get '/'
    assert last_response.ok?
  end
end