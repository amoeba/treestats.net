class App
  get '/rankings/titles/?' do
    @server = params[:server] || "All"

    limit = 100
    sort_order = -1

    @sort_text = "asc"

    # Sorting of records (asc/desc)
    if(params.has_key?('sort'))
      if(params[:sort] == "asc")
        sort_order = 1
        @sort_text = "desc"
      else
        @sort_text = "asc"
      end
    end

    if(params[:server] && params[:server]  != "All")
      match_clause = {
        "$match" => { "ti" => { "$exists" => true },
        "s" => params[:server]}
      }
    else
      match_clause = {
        "$match" => { "ti" => { "$exists" => true }}
      }
    end

    @characters = Character.collection.aggregate(
    match_clause,
    {
      "$project" => {
        "n" => 1,
        "s" => 1,
        "num_titles" => { "$size" => "$ti" }
      }
    },
    {
      "$sort" => { "num_titles" => sort_order }
    },
    {
      "$limit" => limit
    })

    haml :rankings_titles
  end

  get '/rankings/?' do
    not_found if(!params.has_key?("ranking"))

    limit = 100
    sort = -1
    @sort_text = "asc"
    sort_by = params[:ranking] == "titles" ? "ti" : params[:ranking]

    # Process ranking into tokens
    @tokens = params[:ranking].split(".")
    @server = params[:server]

    # Filtering of records (value/server)
    where_clause = { @tokens[0] => { "$exists" => true }}
    where_clause['s'] = params[:server] if params[:server] != "All"


    # Sorting of records (asc/desc)
    if(params.has_key?('sort'))
      if(params[:sort] == "asc")
        sort = 1
        @sort_text = "desc"
      else
        @sort_text = "asc"
      end
    end

    # Reverse the sort for "birth" ranking
    sort = sort * -1 if(@tokens[0] == "birth")
    
    # Prepare sort clause
    sort_clause = { sort_by => sort }


    # Run the query
    @characters = Character.where(where_clause).sort(sort_clause).limit(limit)

    # Map out just the values we need
    @characters = @characters.to_a.collect do |char|
      c = {
        :name => char.name,
        :server => char.server
      }

      if(@tokens.length == 1)
        if(@tokens[0] == "titles")
          c[:value] = char["ti"].length
        elsif(@tokens[0] == "birth")
          c[:value] = char["birth"]
        elsif(@tokens[0] == "unassigned_xp" || @tokens[0] == "deaths")
          c[:value] = add_commas(char[@tokens[0]].to_s)
        else
          c[:value] = char[@tokens[0]]
        end
      else
        c[:value] = char[@tokens[0]][@tokens[1]][@tokens[2]]
      end

      c
    end

    haml :rankings
  end
end
