require 'rubygems'
require 'clockwork'
require 'resque'
require 'uri'

require './app.rb'
require File.expand_path('../graph_data', __FILE__)

include Clockwork

handler { |job|
  puts "starting job"
  Resque.enqueue(job)
}

every 12.hours, GraphWorker
