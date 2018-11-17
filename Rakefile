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

# Other
task :github do
  puts '>> git branch filtered'
  `git branch filtered`

  branches = `git branch -v`
  puts branches

  puts '>> git filter-branch'
  `git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f filtered`

  puts '>> git push --force origin filtered:master'
  `git push --force origin filtered:master`

  puts '>> git branch -D filtered'
  `git branch -D filtered`

  branches = `git branch -v`
  puts branches
end
