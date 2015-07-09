class App < Sinatra::Application
  get '/rankings/?' do
    criteria = {}

    # Tokenize sort field so we can pull the values out
    # This is either 1 or 3 in length
    @tokens = params[:ranking].split(".")


    # Handle criteria

    # Add server if needed
    if(params[:server] && params[:server] != 'All')
      criteria[:server] = params[:server]
    end

    # Add criterion for non-nullness
    criteria[:"#{@tokens[0]}".exists] = true


    # Grab records
    @characters = Character.where(criteria)

    # Collect the records
    @records = @characters.to_a.collect do |char|
      {
        :server => char.server,
        :name => char.name,
        :value => @tokens.length == 1 ? @tokens[0] == "titles" ? char["titles"].length : char[@tokens[0]] : char[@tokens[0]][@tokens[1]][@tokens[2]]
      }
    end

    # Sort values

    if(params && params[:sort]) # Manual sorting
      if(params[:sort] == "asc" || (params[:ranking] == "birth" && params[:sort] == "asc"))
        @sort = "desc"
        @records.sort! { |a,b| a[:value] <=> b[:value] }
      else
        @sort = "asc"
        @records.sort! { |a,b| b[:value] <=> a[:value] }
      end
    else # Default sorting
      if(params[:ranking] == "birth")
        @sort = "desc"
        @records.sort! { |a,b| a[:value] <=> b[:value] }
      elsif(params[:ranking] == "titles")
        @sort = "asc"
        @records.sort! { |a,b| b[:value] <=> a[:value] }
      else
        @sort = "asc"
        @records.sort! { |a,b| b[:value] <=> a[:value] }
      end
    end

    # Limit to the first 100 records
    @records = @records[0..99] if @records.length > 100


    # Add commas to fields where necessary
    # This is done after limiting to 100 records

    if(@tokens.length == 1)
      if(@tokens[0] == "unassigned_xp" || @tokens[0] == "deaths")
        @records = @records.map { |e| e.merge!({:value => add_commas(e[:value].to_s)})}
      end
    end

    haml :rankings
  end
end
