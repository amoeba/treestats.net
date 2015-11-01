require 'rubygems'
require 'clockwork'
require 'resque'
require 'uri'

require './app.rb'
require File.expand_path('../graph_data', __FILE__)

include Clockwork

handler { |job|
  Resque.enqueue(job)
}

every 10.seconds, GraphWorker
