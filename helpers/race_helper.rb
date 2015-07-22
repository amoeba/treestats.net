module RaceHelper
  RACES = {
    1  => "Aluvian",
    2  => "Gharu'ndim",
    3  => "Sho",
    4  => "Viamontian",
    5  => "Shadowbound",
    6  => "Gearknight",
    7  => "Tumerok",
    8  => "Lugian",
    9  => "Empyrean",
    10  => "Penumbraen",
    11 => "Undead",
    12 => "Olthoi",
    13 => "OlthoiAcid"
  }
  
  RACE_ID = {
    "Aluvian" => 1,
    "Gharundim" => 2,
    "Gharu'ndim" => 2,
    "Sho" => 3,
    "Viamontian" => 4,
    "Shadowbound" => 5,
    "Gearknight" => 6,
    "Tumerok" => 7,
    "Lugian" => 8,
    "Empyrean" => 9,
    "Penumbraen" => 10,
    "Undead" => 11,
    "Olthoi" => 12,
    "OlthoiAcid"  => 13
  }
    
  def self.get_race_name(id)
    RACES[id] ? RACES[id] : id
  end
  
  def self.get_race_id(name)
    RACE_ID[name] ? RACE_ID[name] : name
  end
end