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

desc "Adds missing centuries to birth dates (example: 0020 to 2020)"
task "cleanup_birth" do
  characters = Character.where(({'birth' => {'$lt' => Date.parse('1999-01-01')}}) )

  puts "Found #{characters.count}"

  puts "Updating..." if characters.count > 0

  characters.each do |character|
    with_century = DateHelper::ensure_century(character['birth'])

    character.update(birth: with_century)
  end

  puts "Done"

end
