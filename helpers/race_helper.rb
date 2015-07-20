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
    "Aluvian" => 0,
    "Gharundim" => 1,
    "Gharu'ndim" => 1,
    "Sho" => 2,
    "Viamontian" => 3,
    "Shadowbound" => 4,
    "Gearknight" => 5,
    "Tumerok" => 6,
    "Lugian" => 7,
    "Empyrean" => 8,
    "Penumbraen" => 9,
    "Undead" => 10,
    "Olthoi" => 11,
    "OlthoiAcid"  => 12
  }
    
  def self.get_race_name(id)
    RACES[id] ? RACES[id] : id
  end
  
  def self.get_race_id(name)
    RACE_ID[name] ? RACE_ID[name] : name
  end
end