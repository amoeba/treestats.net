class Character
  include Mongoid::Document
  include Mongoid::Timestamps::Short
  
  field :n,   as: :name,            type: String
  field :s,   as: :server,          type: String
  field :r,   as: :race,            type: String
  field :g,   as: :gender,          type: String
  field :ct,  as: :class_template,  type: String
  field :l,   as: :level,           type: Integer
  field :rn,  as: :rank,            type: Integer
  field :t,   as: :title,           type: String
  field :f,   as: :followers,       type: Integer
  field :d,   as: :deaths,          type: Integer
  field :b,   as: :birth,           type: DateTime
  field :tx,  as: :total_xp,        type: Integer
  field :u,   as: :unassigned_xp,   type: Integer
  field :sc,  as: :skill_credits,   type: Integer
  
  field :a,   as: :attribs,         type: Hash
  field :vi,  as: :vitals,          type: Hash
  field :sk,  as: :skills,          type: Hash
  
  field :m,   as: :monarch,         type: Hash
  field :p,   as: :patron,          type: Hash
  field :v,   as: :vassals,         type: Array
  
  field :ve,  as: :version,         type: Integer
  # |document|
    #DateTime.strptime("7/19/2002 10:14:26 PM EST", "%m/%d/%Y %H:%M:%S %p %Z")
    # Convert birth to a date  
    # puts "Convert birth to datetime"
    # puts document.inspect
    
    # if(document.birth)
      # document.birth = DateTime.strptime("#{document.birth} EST", "%m/%d/%Y %H:%M:%S %p %Z")
    # end
    # newval = DateTime.strptime(newdatetime, "%m/%d/%Y %H:%M:%S %p %Z")
    
    # puts "Converting #{document.birth} to #{newval}"
    
    # document.birth = newval
  # end
  
      # "attributes" => {
      #   "strength" => {
      #     "name" => "Strength", "base" => "???", "creation" => "???"
      #   },
      #   "endurance" => {
      #     "name" => "Endurance", "base" => "???", "creation" => "???"
      #   },
      #   "quickness" => {
      #     "name" => "Quickness", "base" => "???", "creation" => "???"
      #   },
      #   "coordination" => {
      #     "name" => "Coordination", "base" => "???", "creation" => "???"
      #   },
      #   "focus" => {
      #     "name" => "Focus", "base" => "???", "creation" => "???"
      #   },
      #   "self" => {
      #     "name" => "Self", "base" => "???", "creation" => "???"
      #   }
      # },
      # "vitals" => {
      #   "health" => {
      #     "name" => "Health", "base" => "???"
      #   },
      #   "stamina" => {
      #     "name" => "Stamina", "base" => "???"
      #   },
      #   "mana" => {
      #     "name" => "Mana", "base" => "???"
      #   }
      # },
      # "skills" => {
      #   "melee_defense" => {
      #     "name" => "melee_defense", "base" => "???", "training" => "???"
      #   },
      #   "missile_defense" => {
      #     "name" => "missile_defense", "base" => "???", "training" => "???"
      #   },
      #   "arcane_lore" => {
      #     "name" => "arcane_lore", "base" => "???", "training" => "???"
      #   },
      #   "magic_defense" => {
      #     "name" => "magic_defense", "base" => "???", "training" => "???"
      #   },
      #   "mana_conversion" => {
      #     "name" => "mana_conversion", "base" => "???", "training" => "???"
      #   },
      #   "item_tinkering" => {
      #     "name" => "item_tinkering", "base" => "???", "training" => "???"
      #   },
      #   "assess_person" => {
      #     "name" => "assess_person", "base" => "???", "training" => "???"
      #   },
      #   "deception" => {
      #     "name" => "deception", "base" => "???", "training" => "???"
      #   },
      #   "healing" => {
      #     "name" => "healing", "base" => "???", "training" => "???"
      #   },
      #   "jump" => {
      #     "name" => "jump", "base" => "???", "training" => "???"
      #   },
      #   "lockpick" => {
      #     "name" => "lockpick", "base" => "???", "training" => "???"
      #   },
      #   "run" => {
      #     "name" => "run", "base" => "???", "training" => "???"
      #   },
      #   "assess_creature" => {
      #     "name" => "assess_creature", "base" => "???", "training" => "???"
      #   },
      #   "weapon_tinkering" => {
      #     "name" => "weapon_tinkering", "base" => "???", "training" => "???"
      #   },
      #   "armor_tinkering" => {
      #     "name" => "armor_tinkering", "base" => "???", "training" => "???"
      #   },
      #   "magic_item_tinkering" => {
      #     "name" => "magic_item_tinkering", "base" => "???", "training" => "???"
      #   },
      #   "creature_enchantment" => {
      #     "name" => "creature_enchantment", "base" => "???", "training" => "???"
      #   },
      #   "item_enchantment" => {
      #     "name" => "item_enchantment", "base" => "???", "training" => "???"
      #   },
      #   "life_magic" => {
      #     "name" => "life_magic", "base" => "???", "training" => "???"
      #   },
      #   "war_magic" => {
      #     "name" => "war_magic", "base" => "???", "training" => "???"
      #   },
      #   "leadership" => {
      #     "name" => "leadership", "base" => "???", "training" => "???"
      #   },
      #   "loyalty" => {
      #     "name" => "loyalty", "base" => "???", "training" => "???"
      #   },
      #   "fletching" => {
      #     "name" => "fletching", "base" => "???", "training" => "???"
      #   },
      #   "alchemy" => {
      #     "name" => "alchemy", "base" => "???", "training" => "???"
      #   },
      #   "cooking" => {
      #     "name" => "cooking", "base" => "???", "training" => "???"
      #   },
      #   "salvaging" => {
      #     "name" => "salvaging", "base" => "???", "training" => "???"
      #   },
      #   "two_handed_combat" => {
      #     "name" => "two_handed_combat", "base" => "???", "training" => "???"
      #   },
      #   "void_magic" => {
      #     "name" => "void_magic", "base" => "???", "training" => "???"
      #   },
      #   "heavy_weapons" => {
      #     "name" => "heavy_weapons", "base" => "???", "training" => "???"
      #   },
      #   "light_weapons" => {
      #     "name" => "light_weapons", "base" => "???", "training" => "???"
      #   },
      #   "finesse_weapons" => {
      #     "name" => "finesse_weapons", "base" => "???", "training" => "???"
      #   },
      #   "missile_weapons" => {
      #     "name" => "missile_weapons", "base" => "???", "training" => "???"
      #   },
      #   "shield" => {
      #     "name" => "shield", "base" => "???", "training" => "???"
      #   },
      #   "dual_wield" => {
      #     "name" => "dual_wield", "base" => "???", "training" => "???"
      #   },
      #   "recklessness" => {
      #     "name" => "recklessness", "base" => "???", "training" => "???"
      #   },
      #   "sneak_attack" => {
      #     "name" => "sneak_attack", "base" => "???", "training" => "???"
      #   },
      #   "dirty_fighting" => {
      #     "name" => "dirty_fighting", "base" => "???", "training" => "???"
      #   },
      #   "summoning" => {
      #     "name" => "summoning", "base" => "???", "training" => "???"
      #   }
      # },
      # "created_at" => Time.now.to_i,
      # "updated_at" => Time.now.to_i
end