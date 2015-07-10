require 'dotenv/tasks' if ENV["RACK_ENV"] != "production"

task :default => :test

desc "Run all tests"
task :test => :dotenv do
  Dir['./spec/**/*_spec.rb'].each { |f| load f }
end

desc "Deploy to GitHub"
task :deploy do
  puts ">> git branch deploy"
  `git branch deploy`

  branches=`git branch -v`
  puts branches

  puts ">> git filter-branch"
  `git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f deploy`

  puts ">> git push --force origin deploy"
  `git push --force origin deploy:master`

  puts ">> git branch -D deploy"
  `git branch -D deploy`

  branches=`git branch -v`
  puts branches
end
