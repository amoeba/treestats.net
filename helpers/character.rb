module Character
  def self.create(values = {}, options = {})
    blank = {
      "race" => "???",
      "gender" => "???",
      "class_template" => "???",
      "level" => "???",
      "rank" => "???",
      "title" => "???",
      "followers" => "???",
      "deaths" => "???",
      "birth" => "???",
      "total_xp" => "???",
      "unassigned_xp" => "???",
      "attributes" => {
        "strength" => {
          "name" => "Strength", "base" => "???", "creation" => "???"
        },
        "endurance" => {
          "name" => "Endurance", "base" => "???", "creation" => "???"
        },
        "quickness" => {
          "name" => "Quickness", "base" => "???", "creation" => "???"
        },
        "coordination" => {
          "name" => "Coordination", "base" => "???", "creation" => "???"
        },
        "focus" => {
          "name" => "Focus", "base" => "???", "creation" => "???"
        },
        "self" => {
          "name" => "Self", "base" => "???", "creation" => "???"
        }
      },
      "vitals" => {
        "health" => {
          "name" => "Health", "base" => "???"
        },
        "stamina" => {
          "name" => "Stamina", "base" => "???"
        },
        "mana" => {
          "name" => "Mana", "base" => "???"
        }
      },
      "skills" => {
        "melee_defense" => {
          "name" => "melee_defense", "base" => "???", "training" => "???"
        },
        "missile_defense" => {
          "name" => "missile_defense", "base" => "???", "training" => "???"
        },
        "arcane_lore" => {
          "name" => "arcane_lore", "base" => "???", "training" => "???"
        },
        "magic_defense" => {
          "name" => "magic_defense", "base" => "???", "training" => "???"
        },
        "mana_conversion" => {
          "name" => "mana_conversion", "base" => "???", "training" => "???"
        },
        "item_tinkering" => {
          "name" => "item_tinkering", "base" => "???", "training" => "???"
        },
        "assess_person" => {
          "name" => "assess_person", "base" => "???", "training" => "???"
        },
        "deception" => {
          "name" => "deception", "base" => "???", "training" => "???"
        },
        "healing" => {
          "name" => "healing", "base" => "???", "training" => "???"
        },
        "jump" => {
          "name" => "jump", "base" => "???", "training" => "???"
        },
        "lockpick" => {
          "name" => "lockpick", "base" => "???", "training" => "???"
        },
        "run" => {
          "name" => "run", "base" => "???", "training" => "???"
        },
        "assess_creature" => {
          "name" => "assess_creature", "base" => "???", "training" => "???"
        },
        "weapon_tinkering" => {
          "name" => "weapon_tinkering", "base" => "???", "training" => "???"
        },
        "armor_tinkering" => {
          "name" => "armor_tinkering", "base" => "???", "training" => "???"
        },
        "magic_item_tinkering" => {
          "name" => "magic_item_tinkering", "base" => "???", "training" => "???"
        },
        "creature_enchantment" => {
          "name" => "creature_enchantment", "base" => "???", "training" => "???"
        },
        "item_enchantment" => {
          "name" => "item_enchantment", "base" => "???", "training" => "???"
        },
        "life_magic" => {
          "name" => "life_magic", "base" => "???", "training" => "???"
        },
        "war_magic" => {
          "name" => "war_magic", "base" => "???", "training" => "???"
        },
        "leadership" => {
          "name" => "leadership", "base" => "???", "training" => "???"
        },
        "loyalty" => {
          "name" => "loyalty", "base" => "???", "training" => "???"
        },
        "fletching" => {
          "name" => "fletching", "base" => "???", "training" => "???"
        },
        "alchemy" => {
          "name" => "alchemy", "base" => "???", "training" => "???"
        },
        "cooking" => {
          "name" => "cooking", "base" => "???", "training" => "???"
        },
        "salvaging" => {
          "name" => "salvaging", "base" => "???", "training" => "???"
        },
        "two_handed_combat" => {
          "name" => "two_handed_combat", "base" => "???", "training" => "???"
        },
        "void_magic" => {
          "name" => "void_magic", "base" => "???", "training" => "???"
        },
        "heavy_weapons" => {
          "name" => "heavy_weapons", "base" => "???", "training" => "???"
        },
        "light_weapons" => {
          "name" => "light_weapons", "base" => "???", "training" => "???"
        },
        "finesse_weapons" => {
          "name" => "finesse_weapons", "base" => "???", "training" => "???"
        },
        "missile_weapons" => {
          "name" => "missile_weapons", "base" => "???", "training" => "???"
        },
        "shield" => {
          "name" => "shield", "base" => "???", "training" => "???"
        },
        "dual_wield" => {
          "name" => "dual_wield", "base" => "???", "training" => "???"
        },
        "recklessness" => {
          "name" => "recklessness", "base" => "???", "training" => "???"
        },
        "sneak_attack" => {
          "name" => "sneak_attack", "base" => "???", "training" => "???"
        },
        "dirty_fighting" => {
          "name" => "dirty_fighting", "base" => "???", "training" => "???"
        },
        "summoning" => {
          "name" => "summoning", "base" => "???", "training" => "???"
        }
      },
      "created_at" => Time.now.to_i,
      "updated_at" => Time.now.to_i
    }

    values.merge(blank)
  end
end