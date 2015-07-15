module RaceHelper
  RACES = {
    0  => "Aluvian",
    1  => "Gharundim",
    2  => "Sho",
    3  => "Viamontian",
    4  => "Shadowbound",
    5  => "Gearknight",
    6  => "Tumerok",
    7  => "Lugian",
    8  => "Empyrean",
    9  => "Penumbraen",
    10 => "Undead",
    11 => "Olthoi",
    12 => "OlthoiAcid"
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