require_relative '../spec_helper'
require './helpers/request_helper'

describe "RequestHelperSpec" do
  include RequestHelper

  # Minimal stand-in for Sinatra's request object
  def request_with_body(str)
    io = StringIO.new(str)
    Struct.new(:body).new(io)
  end

  def request
    @request
  end

  it "parses a JSON body" do
    @request = request_with_body('{"name":"test"}')
    assert_equal({"name" => "test"}, json_body)
  end

  it "rewinds before reading so it works even if the stream was already consumed" do
    @request = request_with_body('{"name":"test"}')
    @request.body.read  # simulate Sinatra/Rack having read it already
    assert_equal({"name" => "test"}, json_body)
  end

  it "halts with 400 on invalid JSON" do
    @request = request_with_body('not json')
    halted_status = nil
    define_singleton_method(:halt) { |status, _msg| halted_status = status; throw :halt }
    catch(:halt) { json_body }
    assert_equal 400, halted_status
  end
end
