require 'rake/testtask'

require './app'
task :default, :test

task :test do
  Rake::TestTask.new do |t|
    t.pattern = "spec/*_spec.rb"
  end
end

task :deploy do
  puts ">> git branch deploy"
  `git branch deploy`
  
  puts ">> git filter-branch"
  `git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption.rb' -f deploy`
  
  puts ">> git push --force origin deploy"
  `git push --force origin:master deploy`
  
  puts ">> git branch -D deploy"
  `git branch -D deploy`
end