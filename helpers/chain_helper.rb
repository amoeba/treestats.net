class Chain
  def initialize(server, name)
    @server = server
    @name = name
  end

  def get_chain
    highest_patron = find_highest_patron
    return "{}" if highest_patron.nil?

    tree = {'name' => highest_patron}
    walk_chain(tree)

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
    limit = 200

    while patron
      limit -= 1
      highest_patron = patron.name

      return highest_patron if limit <= 0

      if patron.patron
        patron = Character.find_by(server: @server, name: patron.patron['name'])
      else
        return highest_patron
      end
    end

    highest_patron
  end

  def walk_chain(current, level = 0)
    character = Character.find_by(server: @server, name: current['name'])

    return if character.nil?

    if(character['vassals'])
      current.merge!({'children' => []})

      character['vassals'].each_with_index do |vassal, i|
        current['children'] << { 'name' => vassal['name'] }
        walk_chain(current['children'][i], level + 1) unless level > 200
      end
    end
  end
end
