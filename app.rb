# Dotenv
Dotenv.load if settings.development?

Dir["./helpers/*.rb"].each { |file| require file }
Dir["./models/*.rb"].each { |file| require file }

set :views, File.dirname(__FILE__) + "/views"

configure do
  # Mongoid
  Mongoid.load!("./config/mongoid.yml")

  # Rollbar
  if settings.production?
    Rollbar.configure do |config|
      config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
    end
  end
end  

not_found do
  haml :not_found
end

get '/' do
  haml :index
end

get "/download/?" do
  haml :download
end

post '/' do
  text = request.body.read

  # VERIFY
  # Before we do anything, verify the message wasn't tampered with
  if settings.production?
    verify = Encryption::decrypt(text)

    if(!verify)
      Log.create(title: "Failed to verify update", message: text)

      return "Failed to verify character update. Character was not saved."
    end
  end

  # PARSE
  # Parse message
  json_text = JSON.parse(text)

  # Remove verification key if it exists
  if (json_text.has_key?("key"))
    json_text = json_text.tap { |h| h.delete("key") }
  end

  # Get the version number out and use it to let the user know to update
  # their plugin
  
  # version_number = json_text["version"]
  
  version_message = nil
  
  # if(version_number == "1") # Version num is a string (accepts 1.2, etc)
  #   version_message = "You're using an old version of TreeStats. " \
  #   "The latest version provides bug fixes and adds TreeStats Accounts, " \
  #   "which let you view all of your characters across accounts. " \
  #   "Please go to treestats.net and get the latest version."
  # end
  
  # Extract information for later in this method
  name = json_text['name']
  server = json_text['server']
  server_pop = json_text['server_population']
  allegiance_name = json_text['allegiance_name']

  # LOGS
  # Check in the update
  Log.create(title: "/", message: text)

  # PLAYER COUNTS
  # Only save a PlayerCount if this message contains one
  if(json_text.has_key?("server_population"))
    json_text = json_text.tap { |h| h.delete('server_population')}
    PlayerCount.create(server: server, count: server_pop)
  end

  # CHARACTER

  # Convert "birth" field so it's stored as DateTime with GMT-5
  if(json_text.has_key?("birth"))
    json_text["birth"] = CharacterHelper::parse_birth(json_text["birth"])
  end

  character = Character.find_or_create_by(name: name, server: server)

  # Assign attributes then touch
  # We do this instead of just using update_attributes
  # because I'd like to update timestamps even when the character
  # update contains no new information.

  character.assign_attributes(json_text)
  character.save
  character.touch

  # Update statistics
  redis.incr "uploads:daily:#{Time.now.utc.strftime("%Y%m%d")}"
  redis.incr "uploads:monthly:#{Time.now.utc.strftime("%Y%m")}"


  # ALLEGIANCE
  Allegiance.find_or_create_by(server: server, name: allegiance_name)

  # RESPONSE
  response_text = ""
  
  if(character.valid?)
    response_text = "Character was updated successfully."
  else
    MailHelper::send("Character update failed!", "<p>Raw Text<br/>#{text}</p> <p>JSON Text<br/>#{json_text}</p>")
    response_text = "Character update failed."
  end
  
  # Add version_text to response text
  response_text = [response_text, version_message].join(" ") if version_message
  
  # Return final response
  response_text
end

post '/message' do
  return "Got your message!"
end
  
post '/account/create/?' do
  body = request.body.read
  fields = JSON.parse(body)

  # Handle case where (somehow) not all fields are sent
  if(!fields.has_key?("name") &&
    !fields.has_key?("password"))
    return "Not all fields were received. Account not created."
  end

  # Validate fields:
  #  Name already exists

  if(Account.where(name: fields["name"]).exists?)
    return "Account with this name already exists."
  end

  # Validate:
  #  Nam or password is wrong format
  #    Name: [a-zA-Z'] {length > 0}
  #    Password: {length > 0}

  if(/^[a-zA-Z'\- ]+$/.match(fields["name"]) == nil)
    return "Account name must only contain a-z, A-Z and '."
  end

  if(fields["password"].length < 1)
    return "Password must be at least one character in length."
  end

  c = Account.create(fields)

  return "Account successfully created."
end

post '/account/login/?' do
  body = request.body.read
  fields = JSON.parse(body)

  if(!fields.has_key?("name") || !fields.has_key?("password"))
    return "Error sending login information to server: Name and password were not specified."
  end

  if(Account.where(name: fields["name"], password: fields["password"]).exists?)
    return "You are now logged in."
  else
    return "Login failed. Name/password not found."
  end
end

get '/account/:account_name/?' do
  @characters = Character.where(account_name: params[:account_name]).all

  haml :account
end

get '/allegiances/:key.json' do |key|
  content_type :json

  @server, @name = key.split("-")
  @characters = Character.where(server: @server, allegiance_name: @name)

  return "{}" if @characters.nil?

  nodes = []
  links = []

  @characters.each_with_index do |c,i|
    # Add character as a node if it doesn't exist
    # Add links
      # Add characters from links as nodes

    source_id = nodes.find_index { |n| n[:name] == c.name }

    if source_id.nil?
      nodes << { :name => c.name, :group => i }
      source_id = nodes.find_index { |n| n[:name] == c.name }
    end

    vassal_names = c.vassals.collect { |v| { "name" => v["name"] } } if c.vassals
    linkages = [c.patron]
    linkages = linkages.concat(vassal_names) if vassal_names
    linkages = linkages.collect { |i| i.nil? ? nil : i["name"] }.reject { |i| i.nil? }

    linkages.each do |l|
      # Find id of source, create otherwise
      target_id = nodes.find_index { |n| n[:name] == l }
      nodes << { :name => l, :group => i } if target_id.nil?
      target_id = nodes.find_index { |n| n[:name] == l }

      links << { :source => source_id, :target => target_id, :value => 1}

      # Find id of target, create otherwise
      target_id = nodes.find_index { |n| n[:name] == l }
      nodes << { :name => l, :group => i } if target_id.nil?
      target_id = nodes.find_index { |n| n[:name] == l }

      links << { :source => source_id, :target => target_id, :value => 1}
    end
  end

  return { "nodes" => nodes, "links" => links }.to_json
end

get '/allegiances/:key' do |key|
  @server, @name = key.split("-")

  @characters = Character.where(server: @server, allegiance_name: @name).limit(100).asc(:name)

  haml :allegiance
end

get '/allegiances/?' do
  @allegiances = Allegiance.all

  haml :allegiances
end

get '/chain/:server/:name?' do |server, name|
  content_type :json

  character = Character.find_by(server: server, name: name)

  return "{}" if character.nil?

  t = Chain.new(server, name)
  tree = t.get_chain

  tree.to_json
end

get '/characters/?' do
  @characters = Character.all.limit(100).desc(:updated_at).where(:attribs.exists => true)

  haml :characters
end

get '/logs/?' do
  @logs = Log.all.desc(:created_at).limit(100)

  haml :logs
end


get '/player_counts/?' do
  haml :player_counts
end

get '/player_counts.json' do
  content_type :json

  response = {}

  player_counts = PlayerCount.all.sort(server: 1, created_at: 1)

  # Remove _id field and respond with json
  if(player_counts.exists?)
    response = player_counts.collect { |pc| {
      :server => pc.server,
      :count => pc.count,
      :timestamp => pc.created_at
    }}.to_json
  end

  response
end

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
  not_found("No ranking specified.") if(!params.has_key?("ranking"))

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

get "/servers/?" do
  haml :servers
end

get '/stats/uploads/daily' do
  value = redis.keys "uploads:daily:*"

  result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(":")[2], :count => redis.get(v).to_i }}

  result.to_json
end

get '/stats/uploads/monthly' do
  value = redis.keys "uploads:monthly:*"

  result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(":")[2], :count => redis.get(v).to_i }}

  result.to_json
end

get '/:server/?' do |server|
  @characters = Character.where(server: server).limit(100).desc(:updated_at).where(:attribs.exists => true)

  haml :server
end

get '/:server/:name.json' do |s,n|
  begin
    @character = Character.find_by(server: s, name: n)
  rescue Mongoid::Errors::DocumentNotFound
    not_found
  end

  content_type 'application/json'
  JSON.pretty_generate(@character.serializable_hash({}).tap {|h| h.delete("id")})
end

get '/:server/:name/?' do |s,n|
  begin
    @character = Character.find_by(server: s, name: n)
  rescue Mongoid::Errors::DocumentNotFound
    not_found
  end

  haml :character
end