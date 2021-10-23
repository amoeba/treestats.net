require "mongo"
require "date"

client = Mongo::Client.new("mongodb://localhost/mongo")
db = client.database
collection = client[:characters]

def fix_nil_birth_dates(collection)
  query  ={
    "b" => {
      "$gt" => Date.parse("1969-01-01"),
      "$lt" => Date.parse("1971-01-01")
    }
  }

  records = collection.find(query)
  puts "Found #{records.count} records that matched"

  result = collection.update_many(query, { "$set" => { "b" => nil }})
  puts result.inspect
end

def fix_centuryless_birth_dates(collection)
  query  ={
    "b" => {
      "$lt" => Date.parse("1999-01-01")
    }
  }

  records = collection.find(query)
  puts "Found #{records.count} records that matched"

  # Adjust each by 2000 years (0020 -> 2020)
  adjustment = 2000

  records.each do |record|
    puts "#{record["s"]}-#{record["n"]} #{record["b"]}"
    newval = record["b"].to_date.next_year(2000).to_time.utc
    puts "Setting new birth of #{newval}"

    result = collection.update_one({
      "s" => record["s"],
      "n" => record["n"]
    }, {
      "$set" => {
        "b" => newval
      }
    })

    puts result.inspect
  end
end
