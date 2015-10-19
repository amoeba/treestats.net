require 'bundler/setup'
Bundler.require(:default)

require './app'
require 'resque/tasks'

task default: :test

task "resque:setup" do
  ENV['QUEUE'] = '*'
end

desc "Alias for resque:work (To run workers on Heroku)"
task "jobs:work" => "resque:work"

task :test do
  Dir['./test/**/*_spec.rb'].each { |f| load f }
end

task :deploy do
  puts '>> git branch deploy'
  `git branch deploy`

  branches = `git branch -v`
  puts branches

  puts '>> git filter-branch'
  `git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f deploy`

  puts '>> git push --force github deploy'
  `git push --force github deploy:master`

  puts '>> git branch -D deploy'
  `git branch -D deploy`

  branches = `git branch -v`
  puts branches
end
