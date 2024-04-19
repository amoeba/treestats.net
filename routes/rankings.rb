module Sinatra
  module TreeStats
    module Routing
      module Rankings
        def self.registered(app)
          app.get '/rankings/?' do
            # Show the listing of rankings if no ranking is provided
            if !params.has_key?("ranking")
              @rankings = RankingsHelper::RANKINGS
              haml :rankings_index
            else
              ranking = params["ranking"].to_sym

              # Check if the ranking exists
              not_found("Ranking '#{ranking.to_s}' does not exist.") if !RankingsHelper::RANKINGS.has_key?(ranking)

              # Set view variables
              @key = RankingsHelper::RANKINGS[ranking][:sort].keys.first
              @display_name = RankingsHelper::RANKINGS[ranking][:display]
              @server = if params.has_key?("server") && params["server"].length > 0
                params["server"]
              else
                 "All"
              end
              @accessor = RankingsHelper::RANKINGS[ranking][:accessor]
              @sort_url = "/rankings"

              # Handle server and sort (and any other that I might add later?)
              param_keys = params.keys
              query_params = [ "ranking=#{ranking}" ]
              query_params << "server=#{params['server']}" if params.has_key?("server")

              if !params.has_key?("sort") || (params.has_key?("sort") && params["sort"] != "reverse")
                query_params << "sort=reverse"
              end

              @sort_url += "?#{query_params.join('&')}" if query_params.length > 0

              # Get and perform the aggregation
              agg_params = RankingsHelper.generate_aggregation_args(ranking, params)
              @results = Character.collection.aggregate(agg_params)

              haml :rankings
            end
          end
        end
      end
    end
  end
end
