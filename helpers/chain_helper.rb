class Chain
  def initialize(server, name)
    @server = server
    @name = name
  end

  def get_chain
    highest_patron = find_highest_patron
    return "{}" if highest_patron.nil?

    walk_chain_it(highest_patron)
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
    return unless character['vassals']
    return if level > 200

    current.merge!('children' => [])

    character['vassals'].each_with_index do |vassal, i|
      current['children'] << { 'name' => vassal['name'] }
      puts "Walking chain to #{current['children'][i]} at level #{level}"
      walk_chain(current['children'][i], level + 1)
    end
  end

  def walk_chain_it(start)
    tree = { 'name' => start, 'children' => nil }
    cursors = [tree]

    max_it = 500

    while max_it > 0 && cursors.length > 0
      if cursors.last.key?('children') && cursors.last['children'].nil?
        record = Character.find_by(server: @server, name: cursors.last['name'])

        if record['vassals'].nil? || record['vassals'].length == 0
          cursors.last.reject! { |k, v| k == 'children' }
        else
          cursors.last['children'] = record['vassals'].map { |v| { 'name' => v['name'], 'children' => nil } }
        end

      end

      if cursors.last['children']
        next_record = cursors.last['children'].find { |v| v.key?('children') && v['children'].nil? }
      else
        next_record = nil
      end

      if next_record
        idx = cursors.last['children'].map { |v| v['name'] }.find_index(next_record['name'])
        cursors << cursors.last['children'][idx]
      else
        cursors.pop
      end

      max_it -= 1
    end

    if max_it == 0
      { 'name' => 'Loop found in tree. An invalid patron/vassal relationship exists in this tree so the tree was not generated.'}
    else
      tree
    end
  end
end
