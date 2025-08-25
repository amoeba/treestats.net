# rankings_helper.rb
#
# Helper module for the /rankings/:ranking route.
require_relative "./app_helper"

module RankingsHelper
  extend AppHelper
  def self.generate_aggregation_args(name, params)
    # Convert name to symbol first if we happened to pass in a String instead
    name = name.to_sym if name.is_a? String

    # Return nil if the ranking is not found
    return nil if !RANKINGS.has_key?(name)

    ranking = RANKINGS[name]

    # Mix in match args from default
    match = MATCH.merge(ranking[:match])

    # Mix in server
    if !params.nil? && params.has_key?("server") && params["server"] != "All"
      if params["server"] == "Retail"
        match = match.merge({ "s" => { "$in" => ServerHelper.retail_servers } })
      elsif params["server"] == "Emulators"
        match = match.merge({ "s" => { "$in" => ServerHelper.servers } })
      else
        match = match.merge({ "s" => params["server"] })
      end
    else
      # Or just remove server entirely
      match.delete("s")
    end

    # Mix in reverse sorting options
    sort = ranking[:sort].clone # Clone so we don't modify the original

    if !params.nil? && params.has_key?("sort") && params["sort"] == "reverse"
      sort[sort.keys.first] = sort[sort.keys.first] * -1
    end

    pipeline = [
      { "$match" => match },
      { "$project" => ranking[:project] },
      { "$sort" => sort },
      { "$limit" => LIMIT }
    ]

    pipeline
  end

  def self.generate_summary_args(name, params)
    # Convert name to symbol first if we happened to pass in a String instead
    name = name.to_sym if name.is_a? String

    # Return nil if the ranking is not found
    return nil if !RANKINGS.has_key?(name)

    ranking = RANKINGS[name]

    # Return nil if no summary configuration exists (opt-in only)
    return nil if !ranking.has_key?(:summary)

    # Mix in match args from default
    match = MATCH.merge(ranking[:match])

    # Mix in server
    if !params.nil? && params.has_key?("server") && params["server"] != "All"
      if params["server"] == "Retail"
        match = match.merge({ "s" => { "$in" => ServerHelper.retail_servers } })
      elsif params["server"] == "Emulators"
        match = match.merge({ "s" => { "$in" => ServerHelper.servers } })
      else
        match = match.merge({ "s" => params["server"] })
      end
    else
      # Or just remove server entirely
      match.delete("s")
    end

    # Get the field we're sorting by (this is what we'll summarize)
    sort_field = ranking[:sort].keys.first

    # Build summary pipeline
    pipeline = [{ "$match" => match }]

    summary_config = ranking[:summary]

    if summary_config == :categorical
      # Simple categorical grouping (gender, race, etc.)
      pipeline << {
        "$group" => {
          "_id" => "$#{sort_field}",
          "count" => { "$sum" => 1 }
        }
      }
      pipeline << {
        "$project" => {
          "_id" => 0,
          "label" => "$_id",
          "count" => 1
        }
      }
    elsif summary_config.is_a?(Array)
      # Check if this is an array of [breakpoint, label] pairs or just breakpoints
      if summary_config.first.is_a?(Array)
        # Array of [breakpoint, label] pairs for custom labels
        boundaries = summary_config.map(&:first)
        label_map = Hash[summary_config.map { |breakpoint, label| [breakpoint, label] }]

        # Use the highest boundary + 1 as the default bucket identifier
        # This ensures the default bucket gets a predictable _id
        default_bucket_id = boundaries.last + 1

        pipeline << {
          "$bucket" => {
            "groupBy" => "$#{sort_field}",
            "boundaries" => boundaries,
            "default" => default_bucket_id
          }
        }

        pipeline << {
          "$project" => {
            "_id" => 0,
            "label" => {
              "$switch" => {
                "branches" => label_map.map { |breakpoint, label|
                  { "case" => { "$eq" => ["$_id", breakpoint] }, "then" => label }
                } + [
                  { "case" => { "$eq" => ["$_id", default_bucket_id] }, "then" => "#{boundaries.last}+" }
                ],
                "default" => "$_id"
              }
            },
            "count" => 1
          }
        }
      else
        # Traditional array of breakpoints - use breakpoint values as labels
        boundaries = summary_config

        pipeline << {
          "$bucket" => {
            "groupBy" => "$#{sort_field}",
            "boundaries" => boundaries,
            "default" => "Other"
          }
        }

        pipeline << {
          "$project" => {
            "_id" => 0,
            "label" => "$_id",
            "count" => 1
          }
        }
      end
    else
      return nil
    end

    # Sort results by label (ascending for meaningful histogram ordering)
    pipeline << { "$sort" => { "label" => 1 } }

    pipeline
  end


  def self.generate_summary_data(name, params = {})
    pipeline = generate_summary_args(name, params)
    return nil if pipeline.nil?

    results = Character.collection.aggregate(pipeline)

    # Convert results to array format for easy consumption
    summary_data = []
    results.each do |doc|
      summary_data << {
        'label' => doc['label'],
        'count' => doc['count']
      }
    end

    summary_data
  end

  # Default / Base pipeline parameters
  # These are merged with explicitly stated pipeline parameters to allow
  # for global settings and per-ranking settings

  MATCH = {
    "r" => { "$nin" => [ "Olthoi Spitter", "Olthoi Soldier" ] },
    "s" => { "$in" => AppHelper.all_servers },
    "ar" => false,
    'l' => { '$not' => {'$gt' => 275 }},
    "n" => { "$regex" => /^[^\+]+/ }
  }

  PROJECT = {
     "$project" => {
        "_id" => 0,
        "n" => 1,
        "s" => 1
    }
  }

  SORT = {
    "$sort" => {}
  }

  LIMIT = 100

  SUMMARY_BREAKS_ATTRIBUTES = [
    [10, "10"], [11, "11+"], [20, "20+"], [30, "30+"], [40, "40+"], [50, "50+"],
    [60, "60+"], [70, "70+"], [80, "80+"], [90, "90+"], [100, "100+"],
    [110, "110+"], [120, "120+"], [130, "130+"], [140, "140+"], [150, "150+"],
    [160, "160+"], [170, "170+"], [180, "180+"], [190, "190+"], [200, "200+"],
    [210, "210+"], [220, "220+"], [230, "230+"], [240, "240+"], [250, "250+"],
    [260, "260+"], [270, "270+"], [280, "280+"], [290, "290+"], [300, "300+"],
    [310, "310+"], [320, "320+"], [330, "330"], [331, "331+"]
    ]

  SUMMARY_BREAKS_VITALS_HEALTH = [
    [0, "0"], [5, "5"], [6, "6+"], [50, "50+"], [100, "100+"], [150, "150+"],
    [200, "200+"], [250, "250+"], [300, "300+"], [341, "341"], [342, "342+"]
  ]

  SUMMARY_BREAKS_VITALS_STAMINA_MANA = [
    [0, "0"], [10, "10"], [11, "11+"], [50, "50+"], [100, "100+"], [150, "150+"],
    [200, "200+"], [250, "250+"], [300, "300+"], [350, "350+"], [400, "400+"],
    [450, "450+"], [486, "486"], [487, "487+"]
  ]

  # Rankings hash
  RANKINGS = {

    # Attributes
    :strength => {
      :display => "Strength (Base)",
      :group => "Attributes",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "a.strength.base" => 1 },
      :sort => { "a.strength.base" => -1 },
      :accessor => Proc.new { |v| v["a"]["strength"]["base"] },
      :summary => SUMMARY_BREAKS_ATTRIBUTES
    },
    :endurance => {
      :display => "Endurance (Base)",
      :group => "Attributes",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "a.endurance.base" => 1 },
      :sort => { "a.endurance.base" => -1 },
      :accessor => Proc.new { |v| v["a"]["endurance"]["base"] },
      :summary => SUMMARY_BREAKS_ATTRIBUTES
    },
    :coordination => {
      :display => "Coordination (Base)",
      :group => "Attributes",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "a.coordination.base" => 1 },
      :sort => { "a.coordination.base" => -1 },
      :accessor => Proc.new { |v| v["a"]["coordination"]["base"] },
      :summary => SUMMARY_BREAKS_ATTRIBUTES
    },
    :quickness => {
      :display => "Quickness (Base)",
      :group => "Attributes",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "a.quickness.base" => 1 },
      :sort => { "a.quickness.base" => -1 },
      :accessor => Proc.new { |v| v["a"]["quickness"]["base"] },
      :summary => SUMMARY_BREAKS_ATTRIBUTES
    },
    :focus => {
      :display => "Focus (Base)",
      :group => "Attributes",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "a.focus.base" => 1 },
      :sort => { "a.focus.base" => -1 },
      :accessor => Proc.new { |v| v["a"]["focus"]["base"] },
      :summary => SUMMARY_BREAKS_ATTRIBUTES
    },
    :self => {
      :display => "Self (Base)",
      :group => "Attributes",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "a.self.base" => 1 },
      :sort => { "a.self.base" => -1 },
      :accessor => Proc.new { |v| v["a"]["self"]["base"] },
      :summary => SUMMARY_BREAKS_ATTRIBUTES
    },

    # Vitals
    :health => {
      :display => "Health (Base)",
      :group => "Vitals",
      :match => { "vi" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "vi.health.base" => 1 },
      :sort => { "vi.health.base" => -1 },
      :accessor => Proc.new { |v| v["vi"]["health"]["base"] },
      :summary => SUMMARY_BREAKS_VITALS_HEALTH
    },
    :stamina => {
      :display => "Stamina (Base)",
      :group => "Vitals",
      :match => { "vi" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "vi.stamina.base" => 1 },
      :sort => { "vi.stamina.base" => -1 },
      :accessor => Proc.new { |v| v["vi"]["stamina"]["base"] },
      :summary => SUMMARY_BREAKS_VITALS_STAMINA_MANA
    },
    :mana => {
      :display => "Mana (Base)",
      :group => "Vitals",
      :match => { "vi" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "vi.mana.base" => 1 },
      :sort => { "vi.mana.base" => -1 },
      :accessor => Proc.new { |v| v["vi"]["mana"]["base"] },
      :summary => SUMMARY_BREAKS_VITALS_STAMINA_MANA
    },

    # Skills
    :alchemy => {
      :display => "Alchemy (Base)",
      :group => "Skills",
      :match => { "sk.alchemy" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.alchemy.base" => 1 },
      :sort => { "sk.alchemy.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["alchemy"]["base"] }
    },
    :arcane_lore => {
      :display => "Arcane Lore (Base)",
      :group => "Skills",
      :match => { "sk.arcane_lore" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.arcane_lore.base" => 1 },
      :sort => { "sk.arcane_lore.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["arcane_lore"]["base"] }
    },
    :armor_tinkering => {
      :display => "Armor Tinkering (Base)",
      :group => "Skills",
      :match => { "sk.armor_tinkering" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.armor_tinkering.base" => 1 },
      :sort => { "sk.armor_tinkering.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["armor_tinkering"]["base"] }
    },
    :assess_creature => {
      :display => "Assess Creature (Base)",
      :group => "Skills",
      :match => { "sk.assess_creature" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.assess_creature.base" => 1 },
      :sort => { "sk.assess_creature.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["assess_creature"]["base"] }
    },
    :assess_person => {
      :display => "Assess Person (Base)",
      :group => "Skills",
      :match => { "sk.assess_person" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.assess_person.base" => 1 },
      :sort => { "sk.assess_person.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["assess_person"]["base"] }
    },
    :cooking => {
      :display => "Cooking (Base)",
      :group => "Skills",
      :match => { "sk" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.cooking.base" => 1 },
      :sort => { "sk.cooking.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["cooking"]["base"] }
    },
    :creature_enchantment => {
      :display => "Creature Enchantment (Base)",
      :group => "Skills",
      :match => { "sk.creature_enchantment" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.creature_enchantment.base" => 1 },
      :sort => { "sk.creature_enchantment.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["creature_enchantment"]["base"] }
    },
    :deception => {
      :display => "Deception (Base)",
      :group => "Skills",
      :match => { "sk.deception" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.deception.base" => 1 },
      :sort => { "sk.deception.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["deception"]["base"] }
    },
    :dirty_fighting => {
      :display => "Dirty Fighting (Base)",
      :group => "Skills",
      :match => { "sk.dirty_fighting" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.dirty_fighting.base" => 1 },
      :sort => { "sk.dirty_fighting.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["dirty_fighting"]["base"] }
    },
    :dual_wield => {
      :display => "Dual Wield (Base)",
      :group => "Skills",
      :match => { "sk.dual_wield" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.dual_wield.base" => 1 },
      :sort => { "sk.dual_wield.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["dual_wield"]["base"] }
    },
    :fletching => {
      :display => "Fletching (Base)",
      :group => "Skills",
      :match => { "sk.fletching" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.fletching.base" => 1 },
      :sort => { "sk.fletching.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["fletching"]["base"] }
    },
    :finesse_weapons => {
      :display => "Finesse Weapons (Base)",
      :group => "Skills",
      :match => { "sk.finesse_weapons" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.finesse_weapons.base" => 1 },
      :sort => { "sk.finesse_weapons.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["finesse_weapons"]["base"] }
    },
    :healing => {
      :display => "Healing (Base)",
      :group => "Skills",
      :match => { "sk.healing" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.healing.base" => 1 },
      :sort => { "sk.healing.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["healing"]["base"] }
    },
    :heavy_weapons => {
      :display => "Heavy Weapons (Base)",
      :group => "Skills",
      :match => { "sk.heavy_weapons" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.heavy_weapons.base" => 1 },
      :sort => { "sk.heavy_weapons.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["heavy_weapons"]["base"] }
    },
    :item_enchantment => {
      :display => "Item Enchantment (Base)",
      :group => "Skills",
      :match => { "sk.item_enchantment" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.item_enchantment.base" => 1 },
      :sort => { "sk.item_enchantment.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["item_enchantment"]["base"] }
    },
    :item_tinkering => {
      :display => "Item Tinkering (Base)",
      :group => "Skills",
      :match => { "sk.item_tinkering" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.item_tinkering.base" => 1 },
      :sort => { "sk.item_tinkering.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["item_tinkering"]["base"] }
    },
    :jump => {
      :display => "Jump (Base)",
      :group => "Skills",
      :match => { "sk.jump" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.jump.base" => 1 },
      :sort => { "sk.jump.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["jump"]["base"] }
    },
    :leadership => {
      :display => "Leadership (Base)",
      :group => "Skills",
      :match => { "sk.leadership" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.leadership.base" => 1 },
      :sort => { "sk.leadership.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["leadership"]["base"] }
    },
    :life_magic => {
      :display => "Life Magic (Base)",
      :group => "Skills",
      :match => { "sk.life_magic" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.life_magic.base" => 1 },
      :sort => { "sk.life_magic.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["life_magic"]["base"] }
    },
    :light_weapons => {
      :display => "Light Weapons (Base)",
      :group => "Skills",
      :match => { "sk.light_weapons" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.light_weapons.base" => 1 },
      :sort => { "sk.light_weapons.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["light_weapons"]["base"] }
    },
    :lockpick => {
      :display => "Lockpick (Base)",
      :group => "Skills",
      :match => { "sk.lockpick" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.lockpick.base" => 1 },
      :sort => { "sk.lockpick.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["lockpick"]["base"] }
    },
    :loyalty => {
      :display => "Loyalty (Base)",
      :group => "Skills",
      :match => { "sk.loyalty" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.loyalty.base" => 1 },
      :sort => { "sk.loyalty.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["loyalty"]["base"] }
    },
    :magic_defense => {
      :display => "Magic Defense (Base)",
      :group => "Skills",
      :match => { "sk.magic_defense" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.magic_defense.base" => 1 },
      :sort => { "sk.magic_defense.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["magic_defense"]["base"] }
    },
    :magic_item_tinkering => {
      :display => "Magic Item Tinkering (Base)",
      :group => "Skills",
      :match => { "sk.magic_item_tinkering" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.magic_item_tinkering.base" => 1 },
      :sort => { "sk.magic_item_tinkering.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["magic_item_tinkering"]["base"] }
    },
    :mana_conversion => {
      :display => "Mana Conversion (Base)",
      :group => "Skills",
      :match => { "sk.mana_conversion" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.mana_conversion.base" => 1 },
      :sort => { "sk.mana_conversion.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["mana_conversion"]["base"] }
    },
    :melee_defense => {
      :display => "Melee Defense (Base)",
      :group => "Skills",
      :match => { "sk.melee_defense" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.melee_defense.base" => 1 },
      :sort => { "sk.melee_defense.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["melee_defense"]["base"] }
    },
    :missile_defense => {
      :display => "Missile Defense (Base)",
      :group => "Skills",
      :match => { "sk.missile_defense" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.missile_defense.base" => 1 },
      :sort => { "sk.missile_defense.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["missile_defense"]["base"] }
    },
    :missile_weapons => {
      :display => "Missile Weapons (Base)",
      :group => "Skills",
      :match => { "sk.missile_weapons" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.missile_weapons.base" => 1 },
      :sort => { "sk.missile_weapons.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["missile_weapons"]["base"] }
    },
    :recklessness => {
      :display => "Recklessness (Base)",
      :group => "Skills",
      :match => { "sk.recklessness" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.recklessness.base" => 1 },
      :sort => { "sk.recklessness.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["recklessness"]["base"] }
    },
    :run => {
      :display => "Run (Base)",
      :group => "Skills",
      :match => { "sk.run" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.run.base" => 1 },
      :sort => { "sk.run.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["run"]["base"] }
    },
    :salvaging => {
      :display => "Salvaging (Base)",
      :group => "Skills",
      :match => { "sk.salvaging" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.salvaging.base" => 1 },
      :sort => { "sk.salvaging.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["salvaging"]["base"] }
    },
    :shield => {
      :display => "Shield (Base)",
      :group => "Skills",
      :match => { "sk.shield" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.shield.base" => 1 },
      :sort => { "sk.shield.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["shield"]["base"] }
    },
    :sneak_attack => {
      :display => "Sneak Attack (Base)",
      :group => "Skills",
      :match => { "sk.sneak_attack" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.sneak_attack.base" => 1 },
      :sort => { "sk.sneak_attack.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["sneak_attack"]["base"] }
    },
    :summoning => {
      :display => "Summoning (Base)",
      :group => "Skills",
      :match => { "sk.summoning" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.summoning.base" => 1 },
      :sort => { "sk.summoning.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["summoning"]["base"] }
    },
    :two_handed_combat => {
      :display => "Two Handed Combat (Base)",
      :group => "Skills",
      :match => { "sk.two_handed_combat" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.two_handed_combat.base" => 1 },
      :sort => { "sk.two_handed_combat.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["two_handed_combat"]["base"] }
    },
    :void_magic => {
      :display => "Void Magic (Base)",
      :group => "Skills",
      :match => { "sk.void_magic" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.void_magic.base" => 1 },
      :sort => { "sk.void_magic.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["void_magic"]["base"] }
    },
    :war_magic => {
      :display => "War Magic (Base)",
      :group => "Skills",
      :match => { "sk.war_magic" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.war_magic.base" => 1 },
      :sort => { "sk.war_magic.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["war_magic"]["base"] }
    },
    :weapon_tinkering => {
      :display => "Weapon Tinkering (Base)",
      :group => "Skills",
      :match => { "sk.weapon_tinkering" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "sk.weapon_tinkering.base" => 1 },
      :sort => { "sk.weapon_tinkering.base" => -1 },
      :accessor => Proc.new { |v| v["sk"]["weapon_tinkering"]["base"] }
    },

    # Other
    :birth => {
      :display => "Birth",
      :group => "Other",
      :match => { "a" => { "$exists" => true }, "b" => { "$ne" => nil } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "b" => 1 },
      :sort => { "b" => 1 },
      :accessor => Proc.new { |v| v["b"] }
    },
    :deaths => {
      :display => "Deaths",
      :group => "Other",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "d" => 1 },
      :sort => { "d" => -1 },
      :accessor => Proc.new { |v| AppHelper.add_commas v["d"] }
    },
    :unassigned_xp => {
      :display => "Unassigned XP",
      :group => "Other",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "u" => 1 },
      :sort => { "u" => -1 },
      :accessor => Proc.new { |v| AppHelper.add_commas v["u"] }
    },
    :total_xp => {
      :display => "Total XP",
      :group => "Other",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "tx" => 1 },
      :sort => { "tx" => -1 },
      :accessor => Proc.new { |v| AppHelper.add_commas v["tx"] }
    },
    :followers => {
      :display => "Followers",
      :group => "Other",
      :match => { "a" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "f" => 1 },
      :sort => { "f" => -1 },
      :accessor => Proc.new { |v| AppHelper.add_commas v["f"] }
    },
    :titles => {
      :display => "Titles",
      :group => "Other",
      :match => { "ti" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "titles" => { "$size" => "$ti" } },
      :sort => { "titles" => -1 },
      :accessor => Proc.new { |v| v["titles"] }
    },
    :times_enlightened => {
      :display => "Times Enlightened",
      :group => "Other",
      :match => { "pr.390" => { "$gt" => 0 } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "pr" => { "390" => 1 } },
      :sort => { "pr.390" => -1 },
      :accessor => Proc.new { |v| v["pr"]["390"] },
      :summary => [
        [0,"0"],
        [1,"1"],
        [2,"2"],
        [3,"3"],
        [4,"4"],
        [5,"5"],
        [6,"6+"],
      ]
    },
    :level => {
      :display => "Level",
      :group => "Other",
      :match => { "l" => { "$gt" => 0 } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "l" => 1 },
      :sort => { "l" => -1 },
      :accessor => Proc.new { |v| v["l"] },
      :summary => [
        [1, "1"], [2, "2-4"], [5, "5"], [6, "6+"], [50, "50+"],
        [100, "100+"], [150, "150+"], [200, "200+"], [250, "250+"], [275, "275"], [276, "276+"]
      ]
    },
    :rank => {
      :display => "Rank",
      :group => "Other",
      :match => { "rn" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "rn" => 1 },
      :sort => { "rn" => -1 },
      :accessor => Proc.new { |v| v["rn"] },
      :summary => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    },

    # Demographics
    :gender => {
      :display => "Gender",
      :group => "Demographics",
      :match => { "g" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "g" => 1 },
      :sort => { "g" => 1 },
      :accessor => Proc.new { |v| v["g"] },
      :summary => :categorical
    },
    :race => {
      :display => "Race",
      :group => "Demographics",
      :match => { "r" => { "$exists" => true } },
      :project => { "_id" => 0, "n" => 1, "s" => 1, "r" => 1 },
      :sort => { "r" => 1 },
      :accessor => Proc.new { |v| v["r"] },
      :summary => :categorical
    }
  }
end
