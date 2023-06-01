def player_counts(servers = nil, range = nil)
  match = if servers.nil?
    {
      "$match" => {
        "s" => {
          "$in" => ServerHelper.all_servers
        }
      }
    }
  elsif servers.length == 1 && servers[0] == "lowerpop"
    {
      "$match" => {
        "s" => {
          "$in" => ServerHelper.servers,
          "$nin" => ["Coldeve", "Reefcull"]
        }
      }
    }
  else
    positive = servers.filter { |s| !s.starts_with?("-")}.map { |s| s.sub(/^+/, "")}
    negative = servers.filter { |s| s.starts_with?("-")}.map { |s| s.sub(/^-/, "")}

    filter = {}

    if positive.length > 0
      filter["$in"] = positive
    end

    if negative.length > 0
      filter["$nin"] = negative
    end

    {
      "$match" => {
        "s" => filter
      }
    }
  end

  group = {
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
  }

  sort = {
    "$sort" => {
      "_id.date" => 1
    }
  }

  project = {
    "$project" => {
      "_id": 0,
      "server" => "$_id.s",
      "date" => "$_id.date",
      "count" => "$max"
    }
  }

  range = "3mo" if range.nil?

  if range && range != "All"
    range_map = {
      "3mo" => 93,
      "6mo" => 186,
      "1yr" => 365
    }

    match["$match"]["c_at"] = {
      "$gte" => Date.today - range_map[range]
    }
  end

  result = PlayerCount.collection.aggregate([match, group, sort, project])

  return result.to_json
end

def latest_player_counts
  latest_counts = PlayerCount.collection.aggregate([
    {
      "$sort" => {
        "c_at" => 1
      }
    },
    {
      "$match" => {
        "c_at" => {
          "$gte" => Date.today - 7
        }
      }
    },
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
    }
  ])

  latest_counts = latest_counts.to_a.sort_by { |s| s["server"] }
  latest_counts.each_with_index do |item,i|
    latest_counts[i]["age"] = AppHelper.relative_time(item["date"])
  end

  JSON.pretty_generate(latest_counts)
end
