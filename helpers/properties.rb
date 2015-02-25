module PropertiesHelper
  PROPERTIES = {
    "218" => { :type => :aug, :name => "Reinforcement of the Lugians"},
    "219" => { :type => :aug, :name => "Bleeargh's Fortitude" },
    "220" => { :type => :aug, :name => "Oswald's Enhancement" },
    "221" => { :type => :aug, :name => "Siraluun's Blessing" },
    "222" => { :type => :aug, :name => "Enduring Calm" },
    "223" => { :type => :aug, :name => "Steadfast Will" },
    "224" => { :type => :aug, :name => "Ciandra's Essence" },
    "225" => { :type => :aug, :name => "Yoshi's Essence" },
    "226" => { :type => :aug, :name => "Jibril's Essence" },
    "227" => { :type => :aug, :name => "Celdiseth's Essence" },
    "228" => { :type => :aug, :name => "Koga's Essence" },
    "229" => { :type => :aug, :name => "Shadow of the Seventh Mule" },
    "230" => { :type => :aug, :name => "Might of the Seventh Mule" },
    "231" => { :type => :aug, :name => "Clutch of the Miser" },
    "232" => { :type => :aug, :name => "Enduring Enchantment" },
    "233" => { :type => :aug, :name => "Critical Protection" },
    "234" => { :type => :aug, :name => "Quick Learner" },
    "235" => { :type => :aug, :name => "Ciandra's Fortune" },
    "236" => { :type => :aug, :name => "Charmed Smith" },
    "237" => { :type => :aug, :name => "Innate Renewal" },
    "238" => { :type => :aug, :name => "Archmage's Endurance" },
    "240" => { :type => :aug, :name => "Enchancement of the Blade ;Turner" },
    "241" => { :type => :aug, :name => "Enchancement of the Arrow ;Turner" },
    "242" => { :type => :aug, :name => "Enchancement of the Mace ;Turner" },
    "243" => { :type => :aug, :name => "Caustic Enhancement" },
    "244" => { :type => :aug, :name => "Fiery Enchancement" },
    "245" => { :type => :aug, :name => "Icy Enchancement" },
    "236" => { :type => :aug, :name => "Storm's Enhancement" },
    "300" => { :type => :aug, :name => "Master of the Steel Circle" },
    "302" => { :type => :aug, :name => "Master of the Four-Fold Path" },
    "310" => { :type => :aug, :name => "Iron Skin of the Invincible" },
    
    "370" => { :type => :rating, :name => "Damage" },
    "371" => { :type => :rating, :name => "Damage Resistance" },
    "372" => { :type => :rating, :name => "Critical" },
    "373" => { :type => :rating, :name => "Critical Resistance" },
    "374" => { :type => :rating, :name => "Critical Damage" },
    "375" => { :type => :rating, :name => "Critical Damage Resistance" },
    "376" => { :type => :rating, :name => "Healing Reduction ??? " },
    "377" => { :type => :rating, :name => "Rating unknown ???" },
    "378" => { :type => :rating, :name => "Rating unknown ???" },
    "379" => { :type => :rating, :name => "Vitality" },
  }
  
  def self.get_property_name(id)
    return PROPERTIES[id] ? PROPERTIES[id][:name] : id
  end
  
  def self.is_type(id, type)
    return PROPERTIES[id] && PROPERTIES[id][:type] == type
  end
end