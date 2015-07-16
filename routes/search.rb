class App
  get '/search/?' do
    criteria = {}

    # Deal with which server we're searching
    if(params[:server] && params[:server] != "All Servers")
      criteria[:server] = params[:server]
    end

    # Deal with whether we're searching players or allegiances
    if(params && params[:character])
      if(params[:character].length >= 0)
        criteria[:name] = /#{Regexp.escape(params[:character])}/i
      end

      puts criteria
      @records = Character.limit(50).asc(:name).where(criteria)
    elsif(params && params[:allegiance])
      if(params[:allegiance].length >= 0)
        criteria[:name] = /#{Regexp.escape(params[:allegiance])}/i
      end

      puts criteria
      @records = Allegiance.limit(50).asc(:server).where(criteria)
    end

    haml :search
  end
end
