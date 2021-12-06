module ServerHelper
  @retail_servers = %w{Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb}

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
      name: "InfiniteAC",
      type: "PvE",
      software: "ACE",
      description: "Single Account - 5x XP - 2X Mob Dmg - Custom Enlightenment System",
      address: "158.69.123.111:9000",
      account_limit: 1
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
      name: "Duskfall",
      type: "PvE",
      software: "ACE",
      description: "10x XP, 5x Luminance, Custom Content/Dungeons/Gear/Story Progression",
      address: "ac.duskfall.net:9000",
      discord: "https://discord.gg/jH7uYyF8gp",
      account_limit: 2
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
      discord: "https://discord.gg/Z5eHEZeW2Z",
      website: "http://ac.circleofseven.com",
    }
  ]

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
    counts = QueryHelper.dashboard_latest_counts

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
