# TODO Optimize queries using projections
# egdb.users.find({age:18}, {name:1})

require 'sinatra'
require 'haml'
require 'mongo'
include Mongo
require 'json/ext'
require 'json'
require 'time'

Dir["./helpers/*.rb"].each { |file| require file }


# Mongo(Mongolab) setup

if(ENV['MONGOLAB_URI'])
  mongo_uri = ENV['MONGOLAB_URI']
  db_name = mongo_uri[%r{/([^/\?]+)(\?|$)}, 1]
  client = MongoClient.from_uri(mongo_uri)
  db = client.db(db_name)
else
  host    = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
  port    = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT
  client = MongoClient.new(host, port)
  db     = client['treestats']
end


# Routes
not_found do
  haml :not_found
end

get '/' do
  haml :index
end

post '/' do
  # TODO
  # Catch failed parse
  # Add all monarchs/patrons/vassals as stubs when you update
  #   This will fix tree code and make the site more full anyway
  #   SUBTODO: Adjust character, rankings, and any other views to be tolerant of this
  # Response

  text = request.body.read
  
  # Before we do anything, verify the message wasn't tampered with
  verify = Encryption::decrypt()
  
  if(!verify)
    db['updates'].insert({
      :title => "Failed to verify update",
      :timestamp => Time.now.to_i,
      :message => text
      })
    
  #   return
  # end
  
  # Parse message
  json_text = JSON.parse(text)
  
  # Remove key
  json_text.tap { |h| h.delete('key')}

  # Updates

  # Check in the update
  db['updates'].insert(json_text.merge({ :timestamp => Time.now.to_i }))


  # Server Populations

  # Save server and server population before processing the character
  server = json_text['server']
  server_pop = json_text['server_population']

  # Remove server_population from json_text
  json_text = json_text.tap { |h| h.delete('server_population')}

  db['serverpops'].insert({
    :server => server,
    :population => server_pop,
    :timestamp => Time.now.to_i
  })


  # Characters

  # Handle character create/update logic
  name = json_text['name']

  # Pre-process "birth" field so it's stored as UNIX time with GMT-5
  if(json_text.has_key?("birth"))
    json_text['birth'] = Time.strptime(json_text['birth'].to_s + " -5", "%m/%d/%Y %H:%M:%S %p %z").to_i
  end

  # Replace character if found, otherwise create
  if(db['characters'].find({:server => server, :name => name}).count > 0)
    db['characters'].update({:server => server, :name => name}, Character.create(json_text))
  else
    db['characters'].insert(Character.create(json_text))
  end


  # Add any monarchs/patrons/vassals we don't already know about

  # Monarch
  if(json_text['monarch'])
    monarch_name = json_text['monarch']['name']
    monarch = db['characters'].find({:name => monarch_name, :server => server})

    if(monarch.count == 0)
      newchar = Character.create({
        'name' => monarch_name,
        'server' => server
        })

        db['characters'].insert(newchar)
    end
  end

  # Patron
  if(json_text['patron'])
    patron_name = json_text['patron']['name']
    patron = db['characters'].find({:name => patron_name, :server => server})

    # Patron record doesn't already exist
    if(patron.count == 0)
      newchar = Character::create({
        'name' => patron_name,
        'server' => server,
        'vassals' => [{
          'name' => name,
          'race' => json_text['race'],
          'rank' => json_text['rank'],
          'title' => json_text['title'],
          'gender' => json_text['gender']
          }]
      })

      if(json_text['monarch'])
        newchar.merge!({
          'monarch' => {
            'name' => json_text['monarch']['name'],
            'race' => json_text['monarch']['race'],
            'rank' => json_text['monarch']['rank'],
            'title' => json_text['monarch']['title'],
            'gender' => json_text['monarch']['gender']
        }})
      end

      db['characters'].insert(newchar)
    else # Patron record does exist
      patron = patron.to_a[0]

      # See if the character isn't in the patron's vassals, add if so
      if(patron['vassals'] && patron['vassals'].length > 0)
        vassals = patron['vassals']

        if(!vassals.collect { |i| i['name']}.include?(name))
          vassals.push({'name' => name})
        end
      end
    end
  end

  # Vassals
  if(json_text['vassals'] && json_text['vassals'].length > 0)
    json_text['vassals'].each do |vassal|
      vassal_name = vassal['name']
      vassal = db['characters'].find({:name => vassal_name, :server => server})

      if(vassal.count == 0)
        newchar = Character.create({
          'name' => vassal_name,
          'server' => server
        })

        if(json_text['monarch'])
          newchar.merge!({
            'monarch' => {
              'name' => json_text['monarch']['name'],
              'race' => json_text['monarch']['race'],
              'rank' => json_text['monarch']['rank'],
              'title' => json_text['monarch']['title'],
              'gender' => json_text['monarch']['gender']
          }})
        end

        if(json_text['patron'])
          newchar.merge!({
            'patron' => {
              'name' => json_text['patron']['name'],
              'race' => json_text['patron']['race'],
              'rank' => json_text['patron']['rank'],
              'title' => json_text['patron']['title'],
              'gender' => json_text['patron']['gender']
          }})
        end

        db['characters'].insert(newchar)
      end
    end

  end

  # RESPOND
  #########
  ""
end

get "/servers/?" do
  haml :servers
end

get '/characters/?' do
  @characters = db['characters'].find({}, {:sort => { 'name' => 1 }}).limit(100)

  haml :characters
end

get '/serverpops.json' do
  serverpops = db['serverpops'].find.to_a.map { |i| i.select { |k,v| k != "_id"} }
  
  response = {}

  if(serverpops.count > 0)
    response = serverpops.to_json
  end
  
  response
end

get '/serverpops/?' do
  haml :serverpops
end

get '/other/:other/?' do |other|
  if(params[:other] == "birth")
    sort = {:sort => { other => 1 }}
  else
    sort = {:sort => { other => -1 }}
  end
  
  @characters = db['characters'].find(
    {params[:other] => { '$not' => /[\?]{3}/}},
    sort
  ).limit(100)

  haml :other
end

get '/tree/:key/?' do
  content_type :json

  server, name = params[:key].split("-")
  character = db['characters'].find({:server => server, :name => name})

  return "{}" if character.count != 1

  character = character.to_a[0]

  t = Tree.new(db, server, name)
  tree = t.get_tree

  tree.to_json
end

get '/rankings/?' do
  criteria = {}

  # Add server if needed
  if(params[:server] != 'All')
    criteria[:server] = params[:server]
  end

  criteria[params[:sort]] = { '$not' => /[\?]{3}/}

  @characters = db['characters'].find(criteria, { :sort => { params[:sort] => -1 }}).limit(100)
  
  # Tokenize sort field so we can pull the values
  @tokens = params[:sort].split(".")
  
  haml :rankings
end

get '/:server/?' do |s|
  @characters = db['characters'].find({'server' => s}, {:sort => { 'name' => 1}}).limit(100)

  haml :server
end

get '/:server/:name.json' do |s,n|
  @character = db['characters'].find({'server' => s, 'name' => n})
  
  response = ""
  
  if @character.count == 1
    response = @character.to_a[0].to_json
  end
  
  response.to_json
end

get '/:server/:name/?' do |s,n|
  @character = db['characters'].find({'server' => s, 'name' => n})

  haml :character
end
