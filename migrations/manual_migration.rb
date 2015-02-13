require 'mongo'
include Mongo
require 'json/ext'
require 'json'
require 'time'

Dir["./helpers/*.rb"].each { |file| require file }

if(ENV['MONGOLAB_URI'])
  mongo_uri = ENV['MONGOLAB_URI']
  db_name = mongo_uri[%r{/([^/\?]+)(\?|$)}, 1]
  client = MongoClient.from_uri(mongo_uri)
  db = client.db(db_name)
else
  host    = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
  port    = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT
  client = MongoClient.new(host, port)
  db     = client['treestats']
end


mongo_uri = "mongodb://heroku_app33484560:na267qh1lj6k0t1f5losadibm4@ds041821.mongolab.com:41821/heroku_app33484560"
client = MongoClient.from_uri(mongo_uri)
db_name = mongo_uri[%r{/([^/\?]+)(\?|$)}, 1]
db = client.db(db_name)

characters = db['characters'].find().to_a

characters.each do |char|
  puts "#{char['birth'].class}" unless char['birth'] == "???"
  
  if char['birth'] != "???"
    #db['characters'].update({:name => char['name'], :server => char['server']}, {'$set' => {'birth' => Time.strptime(char['birth'], "%m/%d/%Y %H:%M:%S %p")}})
    #db['characters'].update({:name => char['name'], :server => char['server']}, {'$set' => {'birth' => Time.parse(char['birth'].to_s).to_i }})
    db['characters'].update({:name => char['name'], :server => char['server']}, {'$set' => {'birth' => char['birth'].to_i }})
  end
  
end