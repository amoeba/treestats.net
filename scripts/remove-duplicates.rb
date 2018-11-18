# Script to delete duplicate characters after I merged Reefcull/ReefCull and
# Hightide/HighTide. After running, only the most recent copy fo the char, as
# determined by most recent updated_at datetime, will remain.
require 'mongo'

# Change this as needed
client = Mongo::Client.new()
db = client.database
collection = client[:characters]

server = "Hightide"
records = collection.find({'s':server})

records.each do |r|
  puts r['n']

  dupes = collection.find({
    's': server, 
    'n': r['n']
  }, {:limit => 5 }).to_a

  next if dupes.length <= 1

  dupes = dupes.sort_by { |i| i['u_at']}

  puts "Duplicates..."
  dupes.each do |record|
    puts "#{record['_id']}/#{record['n']}/#{record['u_at']}"
  end

  to_del = dupes[0..(dupes.length - 2)]

  puts "Deleting..."
  to_del.each do |record|
    puts "#{record['_id']}/#{record['n']}/#{record['u_at']}"
    puts collection.delete_one({'_id': record['_id']})
  end
end
