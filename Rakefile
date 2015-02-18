require 'rake/testtask'

require './app'
task :default, :test

task :test do
  Rake::TestTask.new do |t|
    t.pattern = "spec/*_spec.rb"
  end
end

task :sync do
  # make a new branch off master
  # git filter-branch --index-filter 'git rm --cached --ignore-unmatch private.txt' private  
  # push new branch to master on github
end