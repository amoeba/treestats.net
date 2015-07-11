class App < Sinatra::Application
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
end
