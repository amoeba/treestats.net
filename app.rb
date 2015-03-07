require 'sinatra/base'
require 'json'
require 'mongoid'
require 'json'
require 'haml'

# TODO Optimize queries using projections
# egdb.users.find({age:18}, {name:1})

Dir["./helpers/*.rb"].each { |file| require file }
Dir["./models/*.rb"].each { |file| require file }

module Treestats
  class App < Sinatra::Base
    configure do
      Mongoid.load!("./config/mongoid.yml")
    end

    not_found do
      haml :not_found
    end

    get '/' do
      haml :index
    end

    post '/' do
      # TODO
      # Catch failed parse

      text = request.body.read
      
      # Before we do anything, verify the message wasn't tampered with
      verify = Encryption::decrypt(text)
  
      if(!verify)
        Log.create(title: "Failed to verify update", message: text)
    
        return "Failed to verify character update. Character was not saved."
      end
      
      # Parse message
      json_text = JSON.parse(text)
      
      # Remove verification key if it exists
      if (json_text.has_key?("key"))
        json_text = json_text.tap { |h| h.delete("key") }  
      end
      
      # Updates

      # Check in the update
      Log.create(title: "POST", message: text)

      # Server Populations

      # Save server and server population before processing the character
      server = json_text['server']
      server_pop = json_text['server_population']

      # Remove server_population from json_text
      json_text = json_text.tap { |h| h.delete('server_population')}

      PlayerCount.create(server: server, count: server_pop)
      
      # Characters

      # Handle character create/update logic
      name = json_text['name']
          
      # Pre-process "birth" field so it's stored as DateTime with GMT-5
      if(json_text.has_key?("birth"))
        json_text["birth"] = CharacterHelper::parse_birth(json_text["birth"])
      end
      
      
      character = Character.where(name: name, server: server)
    
      if(character.exists?)
        record = character.first
        
        record.update_attributes(json_text)
        record.touch
      else
        Character.create(json_text)
      end

      # # Add any monarchs/patrons/vassals we don't already know about

      # Monarch
      if(json_text['monarch'])
        monarch_name = json_text['monarch']['name']
        monarch = Character.where(name: monarch_name, server: server)

        if(!monarch.exists?)
          Character.create(name: monarch_name, server: server)
        end
      end

      # Patron
      if(json_text['patron'])
        patron_name = json_text['patron']['name']
        patron = Character.where(name: patron_name, server: server)

        # Patron record doesn't already exist
        if(!patron.exists?)
          patron_attributes = {
            'name' => patron_name,
            'server' => server,
            'vassals' => [{
              'name' => name,
              'race' => json_text['race'],
              'rank' => json_text['rank'],
              'title' => json_text['title'],
              'gender' => json_text['gender']
              }]
          }
          
          # Add monarch if we have that information
          if(json_text['monarch'])
            patron_attributes.merge!({
              'monarch' => {
                'name' => json_text['monarch']['name'],
                'race' => json_text['monarch']['race'],
                'rank' => json_text['monarch']['rank'],
                'title' => json_text['monarch']['title'],
                'gender' => json_text['monarch']['gender']
            }})
          end

          Character.create(patron_attributes)
        else # Patron record does exist
          record = patron.first

          # See if the character isn't in the patron's vassals, add if so
          if(record['vassals'])
            if(!record.vassals.collect { |v| v['name'] }.include?(name))
              record.add_to_set(vassals: { 'name' => name })
            end
          end
          
          record.touch
        end
      end

      # Vassals
      if(json_text['vassals'] && json_text['vassals'].length > 0)
        json_text['vassals'].each do |vassal|
          vassal_name = vassal['name']
          query = Character.where(name: vassal_name, server: server)

          if(!query.exists?)
            vassal_attributes = {
              'name' => vassal_name,
              'server' => server
            }

            if(json_text['monarch'])
              vassal_attributes.merge!({
                'monarch' => {
                  'name' => json_text['monarch']['name'],
                  'race' => json_text['monarch']['race'],
                  'rank' => json_text['monarch']['rank'],
                  'title' => json_text['monarch']['title'],
                  'gender' => json_text['monarch']['gender']
              }})
            end

            if(json_text['patron'])
              vassal_attributes.merge!({
                'patron' => {
                  'name' => json_text['patron']['name'],
                  'race' => json_text['patron']['race'],
                  'rank' => json_text['patron']['rank'],
                  'title' => json_text['patron']['title'],
                  'gender' => json_text['patron']['gender']
              }})
            end

            Character.create(vassal_attributes)
          end
        end

      end

      # RESPOND
      "Character was updated successfully."
    end

    get "/download/?" do
      haml :download
    end
    
    get "/servers/?" do
      haml :servers
    end

    get '/characters/?' do     
     @characters = Character.all.limit(100).desc(:updated_at).where(:attribs.exists => true)

      haml :characters
    end

    get '/search/?' do
      name = nil
      server = nil
      criteria = {}
      
      if(params && params[:name] && params[:name].length >= 3)
        name = /#{Regexp.escape(params[:name])}/i
        
        criteria[:name] = name
      end
      
      if(params[:server] && params[:server] != "All Servers")
        criteria[:server] = params[:server]
      end
        
      @characters = Character.limit(100).where(criteria)
      
      haml :search
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

    get '/player_counts/?' do
      haml :player_counts
    end

    get '/other/:other/?' do |other|
      criteria = {}
      
      # Add server if needed
      if(params[:server] && params[:server] != 'All')
        criteria['server'] = params[:server]
      end
      
      # Sorting
      if(params[:other] == "birth")
        sort = { other => 1 }
      else
        sort = { other => -1 }
      end
      
      @characters = Character.where(criteria).sort(sort)

      haml :other
    end

    get '/tree/:server/:name?' do |server, name|
      content_type :json

      character = Character.find_by(server: server, name: name)
      
      return "{}" if character.nil?

      t = Tree.new(server, name)
      tree = t.get_tree

      tree.to_json
    end

    get '/rankings/?' do
      criteria = {}

      # Tokenize sort field so we can pull the values out
      # This is either 1 or 3 in length
      @tokens = params[:sort].split(".")
      
      
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
          :value => @tokens.length == 1 ? char[@tokens[0]] : char[@tokens[0]][@tokens[1]][@tokens[2]]
        }
      end
      
      # Sort values
      if(@params[:sort] == "birth")
        @records.sort! { |a,b| a[:value] <=> b[:value] }
      else
        @records.sort! { |a,b| b[:value] <=> a[:value] }
      end
      
      
      haml :rankings
    end

    get '/logs/?' do
      @logs = Log.all.desc(:created_at).limit(20)
      
      haml :logs
    end
    
    
    get '/:server/?' do |server|      
      @characters = Character.where(server: server).limit(100).desc(:updated_at).where(:attribs.exists => true)

      haml :server
    end

    get '/:server/:name.json' do |s,n|
      @character = Character.find_by(server: s, name: n)
      
      response = ""
      
      if @character
        response = @character.as_document.tap {|h| h.delete("_id")}.to_json
      end
      
      response.to_json
    end

    get '/:server/:name/?' do |s,n|
      @character = Character.find_by(server: s, name: n)

      haml :character
    end
  end
end