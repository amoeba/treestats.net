# Pre-defined queries to help with caching
module QueryHelper
  def self.dashboard_latest_counts
    PlayerCount.collection.aggregate([
      {
        "$match" => {
          "s" => {
            "$in" => ServerHelper.servers
          }
        }
      },
      {
        "$sort" => {
          "c_at" => 1
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
        "$sort" => {
          "count" => -1
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
        "$limit" => 10
      }
    ]).to_a
  end

  def self.dashboard_total_uploaded
    Character.collection.aggregate([
      {
        "$match" => {
          "s" => {
            "$in" => ServerHelper.servers
          }
        }
      },
      {
        "$group" => {
          "_id" => "$s",
          "count" => { "$sum" => 1 }
        }
      },
      {
        "$sort" => {
          "count" => -1
        }
      },
      {
        "$limit": 10
      }
    ]).to_a
  end
end
