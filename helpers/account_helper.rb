require_relative "./properties_helper"

module AccountHelper
  TABLE_FIELD_MAPPINGS = [
    { :name => "race",
      :label => "Race",
      :group => :general,
      :value => Proc.new { |v| v[:race] }
    },
    {
      :name => "gender",
      :label => "Gender",
      :group => :general,
      :value => Proc.new { |v| v[:gender] }
    },
    {
      :name => "level",
      :label => "Level",
      :group => :general,
      :value => Proc.new { |v| v[:level] }
    },
    {
      :name => "unassigned_xp",
      :label => "Unassigned XP",
      :group => :general,
      :value => Proc.new { |v| AppHelper.add_commas(v[:unassigned_xp]) }
    },
    {
      :name => "luminance_earned",
      :label => "Luminance",
      :group => :general,
      :value => Proc.new { |v| AppHelper.add_commas(v[:luminance_earned]) }
    },
    {
      :name => "current_title",
      :label => "Title",
      :group => :general,
      :value => Proc.new { |v| TitleHelper::get_title_name(v[:current_title]) }
    },
    {
      :name => "birth",
      :label => "Birth",
      :group => :general,
      :value => Proc.new { |v| v[:birth] }
    },
    {
      :name => "aetheria",
      :label => "Aetheria",
      :group => :general,
      :value => Proc.new { |v| PropertiesHelper::AETHERIA_SLOTS[v[:properties]["322"]] }
    },
    {
      :name => "times_enlightened",
      :label => "Time Enlightened",
      :group => :general,
      :value => Proc.new { |v| v[:properties]["390"]}
    },
    {
      :name => "chess_rank",
      :label => "Chess Rank",
      :group => :general,
      :value => Proc.new { |v| v[:properties]["181"]}
    },
    {
      :name => "fishing_skill",
      :label => "Fishing Skill",
      :group => :general,
      :value => Proc.new { |v| v[:properties]["192"]}
    },
    {
      :name => "rank",
      :label => "Rank",
      :group => :allegiance,
      :value => Proc.new { |v| v[:rank] }
    },
    {
      :name => "followers",
      :label => "Followers",
      :group => :allegiance,
      :value => Proc.new { |v| v[:followers] }
    },
    {
      :name => "allegiance_name",
      :label => "Allegiance",
      :group => :allegiance,
      :value => Proc.new { |v| v[:allegiance_name] }
    },
    {
      :name => "monarch",
      :label => "Monarch",
      :group => :allegiance,
      :value => Proc.new { |v| v[:monarch] ? v[:monarch][:name] : "" }
    },
    {
      :name => "patron",
      :label => "Patron",
      :group => :allegiance,
      :value => Proc.new { |v| v[:patron] ? v[:patron][:name] : "" }
    },
    {
      :name => "vassals",
      :label => "Vassals",
      :group => :allegiance,
      :value => Proc.new { |v| v[:vassals] ? v[:vassals].length : "0" }
    },
    {
      :name => "deaths",
      :label => "Deaths",
      :group => :general,
      :value => Proc.new { |v| v[:deaths] }
    },
    {
      :name => "skill_credits",
      :label => "Skill Credits",
      :group => :general,
      :value => Proc.new { |v| v[:skill_credits] }
    },
    {
      :name => "attribs_strength",
      :label => "Strength",
      :group => :attributes,
      :value => Proc.new { |v| v[:attribs]["strength"]["base"] }
    },
    {
      :name => "attribs_endurance",
      :label => "Endurance",
      :group => :attributes,
      :value => Proc.new { |v| v[:attribs]["endurance"]["base"] }
    },
    {
      :name => "attribs_coordination",
      :label => "Coordination",
      :group => :attributes,
      :value => Proc.new { |v| v[:attribs]["coordination"]["base"] }
    },
    {
      :name => "attribs_quickness",
      :label => "Quickness",
      :group => :attributes,
      :value => Proc.new { |v| v[:attribs]["quickness"]["base"] }
    },
    {
      :name => "attribs_focus",
      :label => "Focus",
      :group => :attributes,
      :value => Proc.new { |v| v[:attribs]["focus"]["base"] }
    },
    {
      :name => "attribs_self",
      :label => "Self",
      :group => :attributes,
      :value => Proc.new { |v| v[:attribs]["self"]["base"] }
    },
    {
      :name => "vitals_health",
      :label => "Health",
      :group => :attributes,
      :value => Proc.new { |v| v[:vitals]["health"]["base"] }
    },
    {
      :name => "vitals_stamina",
      :label => "Stamina",
      :group => :attributes,
      :value => Proc.new { |v| v[:vitals]["stamina"]["base"] }
    },
    {
      :name => "vitals_mana",
      :label => "Mana",
      :group => :attributes,
      :value => Proc.new { |v| v[:vitals]["mana"]["base"] }
    },
    {
      :name => "skills_alchemy",
      :label => "Alchemy",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["alchemy"]["base"] }
    },
    {
      :name => "skills_arcane_lore",
      :label => "Arcane Lore",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["arcane_lore"]["base"] }
    },
    {
      :name => "skills_armor_tinkering",
      :label => "Armor Tinkering",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["armor_tinkering"]["base"] }
    },
    {
      :name => "skills_assess_creature",
      :label => "Assess Creature",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["assess_creature"]["base"] }
    },
    {
      :name => "skills_assess_person",
      :label => "Assess Person",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["assess_person"]["base"] }
    },
    {
      :name => "skills_cooking",
      :label => "Cooking",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["cooking"]["base"] }
    },
    {
      :name => "skills_creature_enchantment",
      :label => "Creature Enchantment",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["creature_enchantment"]["base"] }
    },
    {
      :name => "skills_deception",
      :label => "Deception",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["deception"]["base"] }
    },
    {
      :name => "skills_dirty_fighting",
      :label => "Dirty Fighting",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["dirty_fighting"]["base"] }
    },
    {
      :name => "skills_dual_wield",
      :label => "Dual Wield",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["dual_wield"]["base"] }
    },
    {
      :name => "skills_fletching",
      :label => "Fletching",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["fletching"]["base"] }
    },
    {
      :name => "skills_finesse_weapons",
      :label => "Finesse Weapons",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["finesse_weapons"]["base"] }
    },
    {
      :name => "skills_healing",
      :label => "Healing",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["healing"]["base"] }
    },
    {
      :name => "skills_heavy_weapons",
      :label => "Heavy Weapons",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["heavy_weapons"]["base"] }
    },
    {
      :name => "skills_item_enchantment",
      :label => "Item Enchantment",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["item_enchantment"]["base"] }
    },
    {
      :name => "skills_item_tinkering",
      :label => "Item Tinkering",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["item_tinkering"]["base"] }
    },
    {
      :name => "skills_jump",
      :label => "Jump",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["jump"]["base"] }
    },
    {
      :name => "skills_leadership",
      :label => "Leadership",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["leadership"]["base"] }
    },
    {
      :name => "skills_life_magic",
      :label => "Life Magic",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["life_magic"]["base"] }
    },
    {
      :name => "skills_light_weapons",
      :label => "Light Weapons",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["light_weapons"]["base"] }
    },
    {
      :name => "skills_lockpick",
      :label => "Lockpick",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["lockpick"]["base"] }
    },
    {
      :name => "skills_loyalty",
      :label => "Loyalty",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["loyalty"]["base"] }
    },
    {
      :name => "skills_magic_defense",
      :label => "Magic Defense",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["magic_defense"]["base"] }
    },
    {
      :name => "skills_magic_item_tinkering",
      :label => "Magic Item Tinkering",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["magic_item_tinkering"]["base"] }
    },
    {
      :name => "skills_mana_conversion",
      :label => "Mana Conversion",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["mana_conversion"]["base"] }
    },
    {
      :name => "skills_melee_defense",
      :label => "Melee Defense",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["melee_defense"]["base"] }
    },
    {
      :name => "skills_missile_defense",
      :label => "Missile Defense",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["missile_defense"]["base"] }
    },
    {
      :name => "skills_missile_weapons",
      :label => "Missile Weapons",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["missile_weapons"]["base"] }
    },
    {
      :name => "skills_recklessness",
      :label => "Recklessness",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["recklessness"]["base"] }
    },
    {
      :name => "skills_run",
      :label => "Run",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["run"]["base"] }
    },
    {
      :name => "skills_salvaging",
      :label => "Salvaging",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["salvaging"]["base"] }
    },
    {
      :name => "skills_shield",
      :label => "Shield",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["shield"]["base"] }
    },
    {
      :name => "skills_sneak_attack",
      :label => "Sneak Attack",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["sneak_attack"]["base"] }
    },
    {
      :name => "skills_two_handed_combat",
      :label => "Two Handed Combat",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["two_handed_combat"]["base"] }
    },
    {
      :name => "skills_void_magic",
      :label => "Void Magic",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["void_magic"]["base"] }
    },
    {
      :name => "skills_war_magic",
      :label => "War Magic",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["war_magic"]["base"] }
    },
    {
      :name => "skills_weapon_tinkering",
      :label => "Weapon Tinkering",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["weapon_tinkering"]["base"] }
    },
    {
      :name => "skills_summoning",
      :label => "Summoning",
      :group => :skills,
      :value => Proc.new { |v| v[:skills]["summoning"]["base"] }
    },
    {
      :name => "218",
      :label => "Reinforcement of the Lugians",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["218"]}
    },
    {
      :name => "219",
      :label => "Bleeargh's Fortitude",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["219"]}
    },
    {
      :name => "220",
      :label => "Oswald's Enhancement",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["220"]}
    },
    {
      :name => "221",
      :label => "Siraluun's Blessing",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["221"]}
    },
    {
      :name => "222",
      :label => "Enduring Calm",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["222"]}
    },
    {
      :name => "223",
      :label => "Steadfast Will",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["223"]}
    },
    {
      :name => "224",
      :label => "Ciandra's Essence",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["224"]}
    },
    {
      :name => "225",
      :label => "Yoshi's Essence",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["225"]}
    },
    {
      :name => "226",
      :label => "Jibril's Essence",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["226"]}
    },
    {
      :name => "227",
      :label => "Celdiseth's Essence",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["227"]}
    },
    {
      :name => "228",
      :label => "Koga's Essence",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["228"]}
    },
    {
      :name => "229",
      :label => "Shadow of the Seventh Mule",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["229"]}
    },
    {
      :name => "230",
      :label => "Might of the Seventh Mule",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["230"]}
    },
    {
      :name => "231",
      :label => "Clutch of the Miser",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["231"]}
    },
    {
      :name => "232",
      :label => "Enduring Enchantment",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["232"]}
    },
    {
      :name => "233",
      :label => "Critical Protection",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["233"]}
    },
    {
      :name => "234",
      :label => "Quick Learner",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["234"]}
    },
    {
      :name => "235",
      :label => "Ciandra's Fortune",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["235"]}
    },
    {
      :name => "236",
      :label => "Charmed Smith",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["236"]}
    },
    {
      :name => "237",
      :label => "Innate Renewal",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["237"]}
    },
    {
      :name => "238",
      :label => "Archmage's Endurance",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["238"]}
    },
    {
      :name => "240",
      :label => "Enhancement of the Blade Turner",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["240"]}
    },
    {
      :name => "241",
      :label => "Enhancement of the Arrow Turner",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["241"]}
    },
    {
      :name => "242",
      :label => "Enhancement of the Mace Turner",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["242"]}
    },
    {
      :name => "243",
      :label => "Caustic Enhancement",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["243"]}
    },
    {
      :name => "244",
      :label => "Fiery Enhancement",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["244"]}
    },
    {
      :name => "245",
      :label => "Icy Enhancement",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["245"]}
    },
    {
      :name => "246",
      :label => "Storm's Enhancement",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["246"]}
    },
    {
      :name => "298",
      :label => "Eye of the Remorseless",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["298"]}
    },
    {
      :name => "299",
      :label => "Hand of the Remorseless",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["299"]}
    },
    {
      :name => "300",
      :label => "Master of the Steel Circle",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["300"]}
    },
    {
      :name => "301",
      :label => "Master of the Focused Eye",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["301"]}
    },
    {
      :name => "302",
      :label => "Master of the Five Fold Path",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["302"]}
    },
    {
      :name => "309",
      :label => "Frenzy of the Slayer",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["309"]}
    },
    {
      :name => "310",
      :label => "Iron Skin of the Invincible",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["310"]}
    },
    {
      :name => "326",
      :label => "Jack of All Trades",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["326"]}
    },
    {
      :name => "328",
      :label => "Infused Void Magic",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["328"]}
    },
    {
      :name => "294",
      :label => "Infused Creature Magic",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["294"]}
    },
    {
      :name => "295",
      :label => "Infused Item Magic",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["295"]}
    },
    {
      :name => "296",
      :label => "Infused Life Magic",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["296"]}
    },
    {
      :name => "297",
      :label => "Infused War Magic",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["297"]}
    },
    {
      :name => "333",
      :label => "Valor",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["333"]}
    },
    {
      :name => "334",
      :label => "Protection",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["334"]}
    },
    {
      :name => "335",
      :label => "Glory",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["335"]}
    },
    {
      :name => "336",
      :label => "Temperance",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["336"]}
    },
    {
      :name => "338",
      :label => "Aetheric Vision",
      :group => :augmentations,
      :value => Proc.new { |v| v[:properties]["338"]}
    },
    {
      :name => "339",
      :label => "Mana Flow",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["339"]}
    },
    {
      :name => "340",
      :label => "Mana Infusion",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["340"]}
    },
    {
      :name => "342",
      :label => "Purity",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["342"]}
    },
    {
      :name => "343",
      :label => "Craftsman",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["343"]}
    },
    {
      :name => "344",
      :label => "Specialization",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["344"]}
    },
    {
      :name => "365",
      :label => "World",
      :group => :auras,
      :value => Proc.new { |v| v[:properties]["365"]}
    },
    {
      :name => "370",
      :label => "Damage",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["370"]}
    },
    {
      :name => "371",
      :label => "Damage Resistance",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["371"]}
    },
    {
      :name => "372",
      :label => "Critical",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["372"]}
    },
    {
      :name => "373",
      :label => "Critical Resistance",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["373"]}
    },
    {
      :name => "374",
      :label => "Critical Damage",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["374"]}
    },
    {
      :name => "375",
      :label => "Critical Damage Resistance",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["375"]}
    },
    {
      :name => "376",
      :label => "Healing Boost",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["376"]}
    },
    {
      :name => "379",
      :label => "Vitality",
      :group => :ratings,
      :value => Proc.new { |v| v[:properties]["379"]}
    },
    {
      :name => "287",
      :label => "Celestial Hand",
      :group => :other,
      :value => Proc.new { |v| PropertiesHelper.format_society_rank(v[:properties]["287"]) }
    },
    {
      :name => "288",
      :label => "Eldrytch Web",
      :group => :other,
      :value => Proc.new { |v| PropertiesHelper.format_society_rank(v[:properties]["288"]) }
    },
    {
      :name => "289",
      :label => "Radiant Blood",
      :group => :other,
      :value => Proc.new { |v| PropertiesHelper.format_society_rank(v[:properties]["289"]) }
    }
  ]

  def self.fields_for(key)
    TABLE_FIELD_MAPPINGS.select { |h| h[:group] == key }
  end

  def self.field_label(group, name)
    field = TABLE_FIELD_MAPPINGS.select { |h| h[:group] == group.to_sym && h[:name] == name }

    field.length == 1 ? field.first[:label] : ""
  end

  def self.field_value(group, name)
    field = TABLE_FIELD_MAPPINGS.select { |h| h[:group] == group.to_sym && h[:name] == name }

    field.length == 1 ? field.first[:value] : Proc.new { "" }
  end

  def self.parse_birth(birth)
    DateTime.strptime("#{birth} EST", "%m/%d/%Y %H:%M:%S %p %Z")
  end
end
