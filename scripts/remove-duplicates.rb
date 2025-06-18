# Script to delete duplicate characters after I merged Reefcull/ReefCull and
# Hightide/HighTide. After running, only the most recent copy of the char, as
# determined by most recent updated_at datetime, will remain.
require 'mongo'

# Change this as needed
# Remember to use ?authSource=mongo
client = Mongo::Client.new("mongodb://localhost/db")
db = client.database
collection = client[:characters]

def find_and_delete_dupes(collection)
  kept = 0
  deleted = 0
  before = nil
  after = nil

  records = collection.aggregate([
    {
      "$group" => {
        "_id" => {
          "server" => "$s",
          "name" => "$n"
        },
        "count" => {
          "$sum" => 1
        }
      }
    },
    {
      "$match" => {
        "count" => {
          "$gt" => 1
        }
      }
    }
  ])

  before = collection.count

  puts "Found #{records.count} dupes"

  records.each do |r|
    dupes = collection.find({
      "s": r["_id"]["server"],
      "n": r["_id"]["name"]
    }).to_a

    if dupes.length <= 1
      kept += 1
      next
    end

    dupes = dupes.sort_by { |i| i['u_at']}
    to_del = dupes[0..(dupes.length - 2)]

    puts "Deleting...#{to_del[0]["s"]}/#{to_del[0]["n"]} from #{to_del[0]["u_at"].to_f} to #{to_del[to_del.length-2]["u_at"].to_f} but keeping #{dupes[dupes.length-1]["u_at"].to_f}"

    to_del.each do |record|
      deleted += 1
      # collection.delete_one({'_id': record['_id']})
    end
  end

  puts "Kept: #{kept}"
  puts "Deleted #{deleted}"
  after = collection.count
  puts "Of #{before} total records, #{before - after} were deleted"
end

find_and_delete_dupes(collection)
