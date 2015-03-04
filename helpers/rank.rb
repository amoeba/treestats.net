module RankHelper
  RANKS = {
    0 => { # Aluvian
      1 => {
        0 =>  "",
        1 =>  "Yeoman",
        2 =>  "Baronet",
        3 =>  "Baron",
        4 =>  "Reeve",
        5 =>  "Thane",
        6 =>  "Ealdor",
        7 =>  "Duke",
        8 =>  "Aethling",
        9 =>  "King",
        10 => "High King"
      },
      2 => {
        0 =>  "",
        1 =>  "Yeoman",
        2 =>  "Baronet",
        3 =>  "Baroness",
        4 =>  "Reeve",
        5 =>  "Thane",
        6 =>  "Ealdor",
        7 =>  "Duchess",
        8 =>  "Aethling",
        9 =>  "Queen",
        10 => "High Queen"
      }
    },
    1 => { # Gharu
      1 => {
        0 =>  "",
        1 =>  "Sayyid",
        2 =>  "Shayk",
        3 =>  "Maulan",
        4 =>  "Mu'allim",
        5 =>  "Naqib",
        6 =>  "Qadi",
        7 =>  "Mushir",
        8 =>  "Amir",
        9 =>  "Malik",
        10 => "Sultan"
      },
      2 => {
        0 =>  "",
        1 =>  "Sayyida",
        2 =>  "Shayka",
        3 =>  "Mualana",
        4 =>  "Mu'allima",
        5 =>  "Naqiba",
        6 =>  "Qadiya",
        7 =>  "Mushira",
        8 =>  "Amira",
        9 =>  "Malika",
        10 => "Sultana"
      }
    },
    2 => { # Sho
      1 => {
        0 =>  "",
        1 =>  "Jinin",
        2 =>  "Jo-Chueh",
        3 =>  "Nan-Chueh",
        4 =>  "Shi-Chueh",
        5 =>  "Ta-Chueh",
        6 =>  "Kun-Chueh",
        7 =>  "Kou",
        8 =>  "Taikou",
        9 =>  "Ou",
        10 => "Koutei"
      },
      2 => {
        0 =>  "",
        1 =>  "Jinin",
        2 =>  "Jo-Chueh",
        3 =>  "Nan-Chueh",
        4 =>  "Shi-Chueh",
        5 =>  "Ta-Chueh",
        6 =>  "Kun-Chueh",
        7 =>  "Kou",
        8 =>  "Taikou",
        9 =>  "Jo-Ou",
        10 => "Koutei"
      }
    },
    3 => { # Viamontian
      1 => {
        0 =>  "",
        1 =>  "Squire",
        2 =>  "Banner",
        3 =>  "Baron",
        4 =>  "Viscount",
        5 =>  "Count",
        6 =>  "Marquis",
        7 =>  "Duke",
        8 =>  "Grand Duke",
        9 =>  "King",
        10 => "High King"
      },
      2 => {
        0 =>  "",
        1 =>  "Dame",
        2 =>  "Banner",
        3 =>  "Baroness",
        4 =>  "Vicountess",
        5 =>  "Countess",
        6 =>  "Marquise",
        7 =>  "Duchess",
        8 =>  "Grand Duchess",
        9 =>  "Queen",
        10 =>  "High Queen"
      }
    },
    4 => { # Umbrean
      1 => {
        0 =>  "",
        1 =>  "Tenebrous",
        2 =>  "Shade",
        3 =>  "Squire",
        4 =>  "Knight",
        5 =>  "Void Knight",
        6 =>  "Void Lord",
        7 =>  "Duke",
        8 =>  "Archduke",
        9 =>  "Highborn",
        10 => "King"
      },
      2 => {
        0 =>  "",
        1 =>  "Tenebrous",
        2 =>  "Shade",
        3 =>  "Squire",
        4 =>  "Knight",
        5 =>  "Void Knight",
        6 =>  "Viod Lady",
        7 =>  "Duchess",
        8 =>  "Archduchess",
        9 =>  "Highborn",
        10 => "Queen"
      }
    },
    9 => { # Penumbrean
      1 => {
        0 =>  "",
        1 =>  "Tenebrous",
        2 =>  "Shade",
        3 =>  "Squire",
        4 =>  "Knight",
        5 =>  "Void Knight",
        6 =>  "Void Lord",
        7 =>  "Duke",
        8 =>  "Archduke",
        9 =>  "Highborn",
        10 => "King"
      },
      2 => {
        0 =>  "",
        1 =>  "Tenebrous",
        2 =>  "Shade",
        3 =>  "Squire",
        4 =>  "Knight",
        5 =>  "Void Knight",
        6 =>  "Viod Lady",
        7 =>  "Duchess",
        8 =>  "Archduchess",
        9 =>  "Highborn",
        10 => "Queen"
      }
    },
    5 => { # Gear Knight
      1 => {
        0 =>  "",
        1 =>  "Tribunus",
        2 =>  "Praefectus",
        3 =>  "Optio",
        4 =>  "Centurion",
        5 =>  "Principes",
        6 =>  "Legatus",
        7 =>  "Consul",
        8 =>  "Dux",
        9 =>  "Secondus",
        10 => "Primus"
      },
      2 => {
        0 =>  "",
        1 =>  "Tribunus",
        2 =>  "Praefectus",
        3 =>  "Optio",
        4 =>  "Centurion",
        5 =>  "Principes",
        6 =>  "Legatus",
        7 =>  "Consul",
        8 =>  "Dux",
        9 =>  "Secondus",
        10 => "Primus"
      }
    },
    10 => { # Undead
      1 => {
        0 =>  "",
        1 =>  "Neophyte",
        2 =>  "Acolyte",
        3 =>  "Adept",
        4 =>  "Esquire",
        5 =>  "Squire",
        6 =>  "Knight",
        7 =>  "Count",
        8 =>  "Viscount",
        9 =>  "Highness",
        10 => "Annointed"
      },
      2 => {
        0 =>  "",
        1 =>  "Neophyte",
        2 =>  "Acolyte",
        3 =>  "Adept",
        4 =>  "Esquire",
        5 =>  "Squire",
        6 =>  "Knight",
        7 =>  "Countess",
        8 =>  "Viscountess",
        9 =>  "Highness",
        10 => "Annointed"
      }
    },
    8 => { # Empyrean
      1 => {
        0 =>  "",
        1 =>  "Ensign",
        2 =>  "Corporal",
        3 =>  "Lieutenant",
        4 =>  "Commander",
        5 =>  "Commodore",
        6 =>  "Admiral",
        7 =>  "Commodore",
        8 =>  "Warlord",
        9 =>  "Ipharsin",
        10 => "Aulin"
      },
      2 => {
        0 =>  "",
        1 =>  "Ensign",
        2 =>  "Corporal",
        3 =>  "Lieutenant",
        4 =>  "Commander",
        5 =>  "Captain",
        6 =>  "Commodore",
        7 =>  "Admiral",
        8 =>  "Warlord",
        9 =>  "Ipharsia",
        10 => "Aulia"
      }
    },
    6 => { # Tumerok
      1 => {
        0 =>  "",
        1 =>  "Xutua",
        2 =>  "Tuona",
        3 =>  "Ona",
        4 =>  "Nuona",
        5 =>  "Turea",
        6 =>  "Rea",
        7 =>  "Nurea",
        8 =>  "Kauh",
        9 =>  "Sutah",
        10 => "Tah"
      },
      2 => {
        0 =>  "",
        1 =>  "Xutua",
        2 =>  "Tuona",
        3 =>  "Ona",
        4 =>  "Nuona",
        5 =>  "Turea",
        6 =>  "Rea",
        7 =>  "Nurea",
        8 =>  "Kauh",
        9 =>  "Sutah",
        10 => "Tah"
      }
    },
    7 => { # Lugian
      1 => {
        0 =>  "",
        1 =>  "Laigus",
        2 =>  "Raigus",
        3 =>  "Amploth",
        4 =>  "Arintoth",
        5 =>  "Obeloth",
        6 =>  "Lithos",
        7 =>  "Kantos",
        8 =>  "Gigas",
        9 =>  "Extas",
        10 => "Tiatus"
      },
      2 => {
        0 =>  "",
        1 =>  "Laigus",
        2 =>  "Raigus",
        3 =>  "Amploth",
        4 =>  "Arintoth",
        5 =>  "Obeloth",
        6 =>  "Lithos",
        7 =>  "Kantos",
        8 =>  "Gigas",
        9 =>  "Extas",
        10 => "Tiatus"
      }
    }
  }

 
  
  def self.get_rank_name(race, gender, rank)
    rank_name = nil
    
    if RANKS[race] && RANKS[race][gender] && RANKS[race][gender][rank]
      rank_name = RANKS[race][gender][rank]
    end
    
    rank_name
  end
end
