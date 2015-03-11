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
      
      # Extract information for later in this method
      name = json_text['name']
      server = json_text['server']  
      server_pop = json_text['server_population']
      allegiance_name = json_text['allegiance_name']
      
      # LOGS
      # Check in the update
      Log.create(title: "/", message: text)

      # PLAYER COUNTS
      json_text = json_text.tap { |h| h.delete('server_population')}
      PlayerCount.create(server: server, count: server_pop)
      
      # CHARACTER
      
      # Convert "birth" field so it's stored as DateTime with GMT-5
      if(json_text.has_key?("birth"))
        json_text["birth"] = CharacterHelper::parse_birth(json_text["birth"])
      end
      
      character = Character.find_or_create_by(name: name, server: server)
      character.update_attributes(json_text)
    
      # ALLEGIANCE
      Allegiance.find_or_create_by(server: server, name: allegiance_name)
      
      # RESPONSE
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

    get '/allegiances/:key' do |key|
      if(key.length == 2)
        @server, @name = key.split("-")
        @characters = Characters.where(server: server, allegiance_name: name).limit(50).asc(:name)
      end
      
      haml :allegiance  
    end
    
    get '/allegiances/?' do
      @allegiances = Allegiance.all
      
      haml :allegiances
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
      @logs = Log.all.desc(:created_at).limit(100)
      
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