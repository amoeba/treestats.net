# spec/unit/search_route_spec.rb

require_relative '../spec_helper'
require 'rack/test'

class SearchRouteUnit < Minitest::Spec
  include Rack::Test::Methods

  def app
    TreeStats
  end

  before do
    Character.all.destroy
  end

  # Bug 1: /search?server=X (no character param) crashes with NoMethodError
  # Expected: should return all characters on that server
  it "returns all characters when character param is absent" do
    Character.create({"name" => "Alice", "server" => "TestServer"})
    Character.create({"name" => "Bob", "server" => "TestServer"})

    get('/search?server=TestServer')

    assert_equal 200, last_response.status
    body = last_response.body
    assert_includes body, "Found"
    assert_includes body, "2"
    assert_includes body, "results"
    assert_includes body, "Alice"
    assert_includes body, "Bob"
  end

  # Bug 2: /search?server=X&character= crashes with NoMethodError
  # Expected: should return all characters on that server
  it "returns all characters when character param is empty string" do
    Character.create({"name" => "Alice", "server" => "TestServer"})
    Character.create({"name" => "Bob", "server" => "TestServer"})

    get('/search?server=TestServer&character=')

    assert_equal 200, last_response.status
    body = last_response.body
    assert_includes body, "Alice"
    assert_includes body, "Bob"
  end

  # Bug 3: /search?server=X&character (no equals sign) crashes with NoMethodError
  # Rack 3 parses ?character (no =) as nil
  it "returns all characters when character param has no equals sign" do
    Character.create({"name" => "Alice", "server" => "TestServer"})
    Character.create({"name" => "Bob", "server" => "TestServer"})

    get('/search?server=TestServer&character')

    assert_equal 200, last_response.status
    body = last_response.body
    assert_includes body, "Alice"
    assert_includes body, "Bob"
  end

  # Bug 4: Search with character name filter still works
  it "filters characters by name" do
    Character.create({"name" => "Alice", "server" => "TestServer"})
    Character.create({"name" => "Bob", "server" => "TestServer"})

    get('/search?server=TestServer&character=Alice')

    assert_equal 200, last_response.status
    body = last_response.body
    assert_includes body, "Found"
    assert_includes body, "1"
    assert_includes body, "result"
    assert_includes body, "Alice"
    refute_includes body, "Bob"
  end
end
