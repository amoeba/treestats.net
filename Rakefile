require 'bundler/setup'
Bundler.require(:default)

require './app'
require 'resque/tasks'

task default: :test

# Resque
task "resque:setup" do
  ENV['QUEUE'] = '*'
end

desc "Alias for resque:work (To run workers on Heroku)"
task "jobs:work" => "resque:work"

# Testing
task :test do
  Dir['./spec/**/*_spec.rb'].each { |f| load f }
end
