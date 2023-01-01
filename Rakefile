require 'bundler/setup'
Bundler.require(:default)

require './app'
require 'resque/tasks'

task default: :test

# Resque
task 'resque:setup' do
  ENV['QUEUE'] = '*'
end

desc 'Alias for resque:work (To run workers on Heroku)'
task 'jobs:work' => 'resque:work'

namespace :servers do
  desc "Synchronize the application's server list with the community list"
  task :sync do
    require 'nokogiri'
    require 'open-uri'

    url = 'https://raw.githubusercontent.com/acresources/serverslist/master/Servers.xml'
    doc = Nokogiri::HTML(URI.open(url))

    servers = []

    doc.xpath('//serveritem').each do |server|
      servers.push({
                     name: server.xpath('./name').first.content,
                     description: server.xpath('./description').first.content,
                     type: server.xpath('./type').first.content,
                     software: server.xpath('./emu').first.content,
                     host: server.xpath('./server_host').first.content,
                     port: server.xpath('./server_port').first.content,
                     website_url: server.xpath('./website_url').first.content,
                     discord_url: server.xpath('./discord_url').first.content
                   })
    end

    servers = servers.sort_by { |server| server[:name] }
    pp servers
  end
end

# Testing
task :test do
  Dir['./spec/**/*_spec.rb'].each { |f| load f }
end
