require 'rubygems'
require 'clockwork'
require 'resque'
require 'uri'

require './app.rb'
require File.expand_path('../graph_job', __FILE__)
require File.expand_path('../stats_job', __FILE__)

module Clockwork
  handler { |job|
    Resque.enqueue(job)
  }

  every 1.hour, GraphJob
  every 1.hour, StatsJob

end