module ServerHelper
  @retail_servers = %w{Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb}

  @softwares = {
    "GDLE" => "https://www.gdleac.com",
    "ACE" => "https://emulator.ac",
    "ACE-Classic" => "https://github.com/Advan-tage/ACEclassic"
  }

  @servers = [
    {
      name: "Reefcull",
      type: "PvE",
      software: "GDLE",
      description: "Retail experience.",
      address: "reefcull.gdleac.com:9000",
      website: "http://reefcull.gdleac.com",
      discord: "https://discord.gg/Rh3UVRs"
    },
    {
      name: "Harvestbud",
      type: "PvE",
      software: "GDLE",
      description: "Retail experience. Max. 3 accounts.",
      address: "harvestbud.gdleac.com:9000",
      website: "http://harvestbud.gdleac.com",
      discord: "https://discord.gg/Rh3UVRs",
      account_limit: 3
    },
    {
      name: "Hightide",
      type: "PvP",
      software: "GDLE",
      description: "PvP Testing grounds.",
      address: "158.69.54.138:9080",
      discord: "https://discord.gg/6u6G2GTj"
    },
    {
      name: "Coldeve",
      type: "PvE",
      software: "ACE",
      description: "Retail experience.",
      address: "play.coldeve.online:9000",
      discord: "https://discord.gg/nUR4PHe"
    },
    {
      name: "Drunkenfell",
      type: "PvE",
      software: "ACE",
      description: "End-of-retail with modifications.",
      address: "df.drunkenfell.com:9000",
      discord: "https://discord.gg/tHEe7QU"
    },
    {
      name: "LeafDawn",
      type: "PvE",
      software: "ACE",
      description: "Retail experience with light focus on custom content.",
      address: "leafdawn.hopto.org:9000",
      discord: "https://discord.gg/ZKN8dTFMz7"
    },
    {
      name: "Levistras",
      type: "PvE",
      software: "ACE",
      description: "Retail experience. Max. 2 accounts. No botting.",
      address: "levistras.acportalstorm.com:9000",
      discord: "https://discord.gg/aD2t6Yb",
      account_limit: 2
    },
    {
      name: "Thistlecrown",
      type: "PvE",
      software: "ACE",
      description: "Retail experience with convenience changes.",
      address: "thistlecrown.ddns.net:9000",
      discord: "https://discord.gg/uhZ3hn7"
    },
    {
      name: "Seedsow",
      type: "PvE",
      software: "GDLE-Classic",
      description: "We are a Release-Dark Majesty based server which means that you will find dungeons that were once re-tiered restored to there former glory!",
      address: "serafino.ddns.net:9060",
      website: "https://seedsow.ca/",
      discord: "https://discord.gg/HB7c38rWGW"
    },
    {
      name: "Snowreap",
      type: "PvP",
      software: "GDLE-Classic",
      description: "We are a RED Release-Dark Majesty based server which means that you will find dungeons that were once re-tiered restored to there former glory!",
      address: "serafino.ddns.net:9070",
      website: "https://seedsow.ca/",
      discord: "https://discord.gg/zFrBsERp8A"
    },
    {
      name: "Asheron4Fun.com",
      type: "PvE",
      software: "ACE",
      description: "End of Retail experience w/ custom content. 2x XP weekends. Max 4 accounts.",
      address: "www.asheron4fun.com:9000",
      discord: "https://discord.gg/afnQNXj",
      website: "https://www.asheron4fun.com",
      account_limit: 4
    },
    {
      name: "Frostcull",
      type: "PvE",
      software: "ACE",
      description: "10x XP/Lum, 25x Drop Rate, No Level Cap, Custom Content, and More!",
      address: "frostcull.ddns.net:9000",
      discord: "https://discord.gg/RQF7HgEZn4",
      account_limit: 5
    },
    {
      name: "Jellocull",
      type: "PvE",
      software: "ACE",
      description: "Retail experience w/ progressive custom content. 1x XP.",
      address: "ac.jellocull.com:9000",
      discord: "https://discord.gg/snv52pX",
    },
    {
      name: "AChard",
      type: "PvP",
      software: "ACE",
      description: "ACE Retail PVP Server with Custom PK Content. Limit 4 Connections.",
      address: "a-chard.ddns.net:9000",
      discord: "https://discord.gg/gmHfqt2J2D",
      website: "http://ac.circleofseven.com",
    },
    {
      name: "Podtide",
      type: "PvP",
      software: "ACE",
      description: "Where the PvP happens",
      address: "podtide.ddns.net:9000",
      discord: "https://discord.gg/MQEfzwTddG",
      website: "http://podtide.com",
      account_limit: 4
    },
    {
      name: "Killiakta",
      type: "PvE",
      software: "ACE",
      description: "PvE (nearly) infinite level server offering end of retail as well as custom content to include new land masses not seen ingame (even a PKL only landmass), updates to add viability to nostalgic quests, and more!",
      address: "killiakta.ddns.net:9000",
      discord: "https://discord.gg/uaDGHU8ucW",
      account_limit: 2
    },
    {
      name: "Morntide",
      type: "PvE",
      software: "ACE",
      description: "PvE. Retail experience. Max. 3 accounts.",
      address: "morntide.shard.ac:9000",
      discord: "https://discord.gg/7Gcc2XFqhJ",
      website: "https://morntide.ac",
      account_limit: 3
    },
    {
      name: "FunkyTown 2.0",
      type: "PvE",
      software: "GDLE",
      description: "We have exclusive content that can't be found anywhere else! We offer a retail experience with something new to do. \"Funky Island\". PvE and PvP welcome.  WE LOVE AC!",
      address: "funkytownac.com:9050",
      discord: "https://discord.gg/4gzFWTMu",
      website: "https://www.funkytownac.com",
      account_limit: 4
    },
    {
      name: "Morgentau",
      type: "PvE",
      software: "ACE",
      description: "PvE. Retail experience. Max. 6 connections.",
      address: "morgentau.online:9000",
      discord: "https://discord.gg/B3mYXdavTr",
      website: "https://forum.morgentau.online/index.php",
      account_limit: 6
    },
    {
      name: "Derptide",
      type: "PvE",
      software: "ACE",
      description: "Retail with many QoL improvements most quest rewards updated to be usable, and useful for the leading experience, ongoing story arcs and live events.",
      address: "ac.derptide.net:9000",
      discord: "https://discord.gg/TgGrbFey",
      account_limit: 3
    },
    {
      name: "Wynterthaw",
      type: "PvE",
      software: "ACE",
      description: "Custom content created for lower and post 275 life.  Entire new island for 275+.",
      address: "71.87.108.159:9000",
      discord: "https://discord.gg/uWUgNv2yDP",
      account_limit: 3
    },
    {
      name: "Shadowland",
      type: "PvE",
      software: "ACE",
      description: "PvE Retail. Standard settings. No max on accounts.",
      address: "shadowland.zapto.org:9000"
    },
    {
      name: "Pourtide",
      type: "PvP",
      software: "ACE",
      description: "PvP Server. Custom Content but mainly focusing on PvP Aspects. Hellgates currently active on this server. Max level 126 may change in the future. Only majors.",
      address: "pourtide.ddns.net:9000",
      discord: "https://discord.gg/SwqTnYBdEH",
      account_limit: 2
    },
    {
      name: "FrostfACE",
      type: "PvE",
      software: "ACE",
      description: "New accounts include lvl 275 starter characters. Retail character restoration also supported.",
      address: "172.111.230.127:9000"
    },
    {
      name: "Infinite Frosthaven",
      type: "PvE",
      software: "ACE",
      description: "Active play rewarded! Earn permanent account-wide increased XP% from completing quests. No level cap. Magic learned from looted scrolls only. Custom content.",
      address: "ifh.ddns.net:9000",
      discord: "https://discord.gg/zdQVP7bmjC"
    },
    {
      name: "DARKSIDE-PK",
      type: "PvE",
      software: "ACE",
      description: "Retail experience. 3x.",
      address: "daksidegaming.ddns.net:9000"
    },
    {
      name: "ValHeel",
      type: "PvE",
      software: "ACE",
      description: "PvE. Post End-of-Retail content. Level 300 Cap.",
      address: "162.250.127.186:9000",
      account_limit: 2,
      discord: "https://discord.gg/Xwn2NZE2rd"
    },
    {
      name: "Dekarutide",
      type: "PvP",
      software: "ACE-Classic",
      description: "ACE-Classic Dark Majesty era custom server, with new skills, techniques, tactics, endless hybrid template possibilities.",
      address: "147.135.30.224:9000",
      account_limit: 2,
      discord: "https://discord.gg/GbAtfwNwKj"
    },
    {
      name: "Doctide",
      type: "PvP",
      software: "ACE",
      description: "Where all the PvP happens.",
      address: "doctide.online:9000",
      account_limit: 3,
      discord: "https://discord.gg/Qts4sF58H6",
      website: "http://doctide.online"
    }
  ]

  def self.softwares
    @softwares
  end

  def self.retail_servers
    @retail_servers
  end

  def self.servers
    @servers.map { |s| s[:name] }
  end

  def self.all_servers
    retail_servers + servers
  end

  def self.server_details
    @servers
  end

  # @servers, enhanced with player counts
  def self.servers_with_counts
    servers = @servers
    counts = QueryHelper.latest_player_counts

    servers.each do |server|
      count = counts.find { |count| server[:name] == count[:server]}

      next unless count

      server[:players] = {
        count: count[:count],
        updated_at: count[:date],
        age: AppHelper.relative_time(count[:date])
      }
    end

    servers
  end
end
