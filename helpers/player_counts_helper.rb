def player_counts(servers = nil)
  filter_to = servers || ServerHelper.servers

  # Get max counts by date & server
  # TODO: Filter to only allowed servers
  result = PlayerCount.collection.aggregate([
    {
      "$match" => {
        "c_at" => {
          "$gte" => Date.today - 120
        },
        "s" => {
          "$in" => filter_to
        }
      }
    },
    {
      "$group" => {
        "_id" => {
          "s" => "$s",
          "date" => {
            "$dateToString" => {
              "format" => "%Y%m%d",
              "date" => "$c_at"
            }
          }
        },
        "max" => { "$max" => "$c" }
      }
    },
    "$sort" => {
      "_id.date" => 1
    }
  ])

  # Restructure result for better JSON shape
  pops = {}

  result.each do |r|
    pops[r["_id"]["s"]] ||= []
    pops[r["_id"]["s"]] << {
      :date => r["_id"]["date"],
      :count => r["max"]
    }
  end

  pops.to_json
end

def latest_player_counts
  latest_counts = PlayerCount.collection.aggregate([
    {
      "$group" =>
        {
          "_id" => "$s",
          "count" => {
            "$last" => "$c"
          },
          "created_at" => {
            "$last" => "$c_at"
          }
        }
    },
    {
      "$project" => {
        "_id": 0,
        "server": "$_id",
        "count": "$count",
        "date": "$created_at"
      }
    },
    {
      "$sort" => {
        "c_at" => 1
      }
    }
  ])

  latest_counts = latest_counts.to_a.sort_by { |s| s["server"] }
  latest_counts.each_with_index do |item,i|
    latest_counts[i]["age"] = AppHelper.relative_time(item["date"])
  end

  JSON.pretty_generate(latest_counts)
end
