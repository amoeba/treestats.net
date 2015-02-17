require 'rake/testtask'

require './app'
task :default, :test

task :test do
  Rake::TestTask.new do |t|
    t.pattern = "spec/*_spec.rb"
  end
end