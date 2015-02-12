class Tree
  def initialize(db, server, name)
    @db = db
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
    character = @db['characters'].find({:server => @server, :name => @name})

    # Return early if we're done
    return nil if character.count != 1

    # Grab the character directly
    character = character.to_a[0]

    # Return early if no patron
    return character['name'] if !character['patron']

    highest_patron = character['patron']['name']

    # Do the finding
    patron = @db['characters'].find({:server => @server, :name => character['patron']['name']}) if character['patron']

    # Trarverse upward toward the ultimate patron
    while patron.count == 1
      patron = patron.to_a[0]

      highest_patron = patron['name']

      if !patron['patron'].nil?
        patron = @db['characters'].find({:server => @server, :name => patron['patron']['name']})
      else
        return highest_patron
      end
    end

    highest_patron
  end

  def walk_tree(current)
    character = @db['characters'].find({:server => @server, :name => current['name']})

    return if character.count != 1
    
    character = character.to_a[0]

    if !character['vassals'].nil?
      current.merge!({'children' => []})

      character['vassals'].each_with_index do |vassal, i|
        current['children'] << { 'name' => vassal['name'] }
        walk_tree(current['children'][i])
      end
    end
  end
end