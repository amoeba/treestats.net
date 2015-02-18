require 'rake/testtask'

require './app'
task :default, :test

task :test do
  Rake::TestTask.new do |t|
    t.pattern = "spec/*_spec.rb"
  end
end

task :deploy do
  `git branch deploy`
  `git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption.rb' deploy`
  `git push --force origin deploy`
  `git branch -D deploy`
end