module StatsHelper
  module CharacterStats
    def self.sum_of_builds
      result = Character.collection.aggregate([
        {
          "$match" => {
            "a" => { "$exists" => true},
            "r" => { "$nin" => [ "Olthoi Spitter", "Olthoi Soldier" ] }
          }
        },
        {
          "$group" => {
            "_id" => {
              "strength" => "$a.strength.creation",
              "endurance" => "$a.endurance.creation",
              "coordination" => "$a.coordination.creation",
              "quickness" => "$a.quickness.creation",
              "focus" => "$a.focus.creation",
              "self" => "$a.self.creation"
            },
            "count" => { "$sum" => 1}
          }
        }
      ])

      # Return result
      values = []

      # Process
      result.each do |doc|
         values <<  {
           'x' => %w[strength endurance coordination quickness focus self].map { |a| doc['_id'][a] }.join("/"),
           'y' => doc['count']
         }
      end

      values
    end

    def self.sum_of_attributes
      result = Character.collection.aggregate([
        {
          "$match" => {
            "a" => { "$exists" => true},
            "r" => { "$nin" => [ "Olthoi Spitter", "Olthoi Soldier" ] }
          }
        },
        {
          "$group" => {
            "_id" => nil,
            "Strength" => { "$sum" => "$a.strength.base" },
            "Endurance" => { "$sum" => "$a.endurance.base" },
            "Coordination" => { "$sum" => "$a.coordination.base" },
            "Quickness" => { "$sum" => "$a.quickness.base" },
            "Focus" => { "$sum" => "$a.focus.base" },
            "Self" => { "$sum" => "$a.self.base" }
          }
        },
        {
          "$project" => {
            "_id" => 0,
            "Strength" => 1,
            "Endurance" => 1,
            "Coordination" => 1,
            "Quickness" => 1,
            "Focus" => 1,
            "Self" => 1
          }
        }
      ])

      values = []
      doc = result.first

      if doc.nil?
        return values
      end

      doc.keys.each do |key|
        values << { 'x' => key, 'y' => doc[key]}
      end

      values
    end

    def self.count_of_races
      result = Character.collection.aggregate([
        {
          "$group" => {
            "_id" => "$r",
            "count" => { "$sum" => 1 }
          }
        }
        ])

      # Return result
      values = []

      # Process
      result.each { |doc| values <<  { 'x' => doc['_id'], 'y' => doc['count'] } }

      # Filter
      values.select { |v| !v['x'].nil? && v['x'].length > 2 }
    end

    def self.count_of_genders
      result = Character.collection.aggregate([
        {
          "$group" => {
            "_id" => "$g",
            "count" => { "$sum" => 1 }
          }
        }
        ])


      # Return result
      values = []

      # Process
      result.each { |doc| values <<  { 'x' => doc['_id'], 'y' => doc['count'] } }

      # Filter
      values.select { |v| v['x'] == "Male" || v['x'] == "Female" }
    end

    def self.count_of_ranks
      result = Character.collection.aggregate([
        {
          "$group" => {
            "_id" => "$rn",
            "count" => { "$sum" => 1 }
          }
        }
        ])

      # Return result
      values = []

      # Process
      result.each { |doc| values <<  { 'x' => doc['_id'], 'y' => doc['count'] } }

      # Filter
      values.select { |v| !v['x'].nil? }
    end

    def self.count_of_levels
      result = Character.collection.aggregate([
        {
          "$group" => {
            "_id" => "$l",
            "count" => { "$sum" => 1 }
          }
        }
        ])

      # Return result
      values = []

      # Process
      result.each { |doc| values <<  { 'x' => doc['_id'], 'y' => doc['count'] } }

      # Filter
      values.select { |v| !v['x'].nil? }
    end
  end
end
