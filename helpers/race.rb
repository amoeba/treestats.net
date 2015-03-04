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
  
  def self.get_race_name(id)
    RACES[id] ? RACES[id] : id
  end
end