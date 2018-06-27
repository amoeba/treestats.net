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

  latest_counts = latest_counts.to_a
  latest_counts.each_with_index do |item,i|
    latest_counts[i]["age"] = relative_time(item["date"])
  end

  JSON.pretty_generate(latest_counts)
end
