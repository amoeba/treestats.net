class Tree
  def initialize(server, name)
    @server = server
    @name = name
  end

  def get_tree
    highest_patron = find_highest_patron
    return "{}" if highest_patron.nil?

    tree = {'name' => highest_patron}
    walk_tree(tree)

    tree
  end

  def find_highest_patron
    highest_patron = nil

    # Find the character
    character = Character.find_by(server: @server, name: @name)

    # Return early if we're done
    return nil if character.nil?

    # Return early if no patron
    return character.name if !character.patron
    
    highest_patron = character.patron['name']
    
    # Do the finding
    patron = Character.find_by(server: @server, name: highest_patron)
    
    # Traverse upward toward the ultimate patron
    while patron
      highest_patron = patron.name

      if(patron.patron)
        patron = Character.find_by(server: @server, name: patron.patron['name'])
      else
        return highest_patron
      end
    end

    highest_patron
  end

  def walk_tree(current)
    # Find the current level's parent
    character = Character.find_by(server: @server, name: current['name'])
    
    puts "Reached leaf" if character.nil?
    return if character.nil?

    # Find any disconnected vassals for this level's parent
    vassals = Character.where({ :server => @server, :'p.name' => current['name'] })
    
    puts "Before"
    puts character['vassals']
    
    # Create the union of connected and disconnected vassals for this level's parent
    all_vassals = []
    all_vassals = all_vassals.concat(character['vassals'].collect { |v| v['name'] }) if character['vassals']
    all_vassals = all_vassals.concat(vassals.collect { |v| v['name']}) if vassals && vassals.count > 0
    
    puts "After"
    puts all_vassals
    
    # Add each vassal from the above union to this level's parent and recurse
    if(all_vassals.length > 0)
      current.merge!({'children' => []})

      all_vassals.each_with_index do |v,i|
        current['children'] << { 'name' => v }
        
        walk_tree(current['children'][i])
      end
      
      # all_vassals.each do |v|
      #   current['children'] << { 'name' => v['name'] }
      # end
    end
  end
end