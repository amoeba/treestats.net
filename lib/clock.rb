require 'rubygems'
require 'clockwork'
require 'resque'
require 'uri'

require './app.rb'
require File.expand_path('../query_cache_job', __FILE__)

module Clockwork
  handler { |job|
    Resque.enqueue(job)
  }

  every 3.minutes, QueryCacheJob
end