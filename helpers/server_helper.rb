module ServerHelper
  @retail_servers = %w{Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb}

  @servers = [
    {
      name: "Reefcull",
      type: "GDLE",
      description: "PvE. Retail experience.",
      address: "reefcull.gdleac.com:9000",
      website: "http://reefcull.gdleac.com",
      discord: "https://discord.gg/Rh3UVRs"
    },
    {
      name: "Hightide",
      type: "GDLE",
      description: "PvP. Retail experience.",
      address: "hightide.connect-to-server.online:9000",
      website: "http://hightide.connect-to-server.online",
      discord: "https://discord.gg/Rh3UVRs"
    },
    {
      name: "Harvestbud",
      type: "GDLE",
      description: "PvE. Retail experience. Max. 3 accounts.",
      address: "harvestbud.gdleac.com:9000",
      website: "http://harvestbud.gdleac.com",
      discord: "https://discord.gg/Rh3UVRs"
    },
    {
      name: "Riptide",
      type: "GDLE",
      description: "A PvP server that will mimic retail with quality of life deviations.",
      address: "riptide.ac:9000",
      website: "http://acriptide.herokuapp.com",
      discord: "https://discord.gg/SZsTGh"
    },
    {
      name: "Coldeve",
      type: "ACE",
      description: "PvE. Retail experience.",
      address: "play.coldeve.online:9000",
      discord: "https://discord.gg/aXtZB4"
    },
    {
      name: "Drunkenfell",
      type: "ACE",
      description: "PvE. End-of-retail with modifications.",
      address: "df.drunkenfell.com:9000",
      discord: "https://discord.gg/tHEe7QU"
    },
    {
      name: "LeafDawn",
      type: "ACE",
      description: "PvE. Retail experience with light focus on custom content.",
      address: "leafdawn.hopto.org:9000",
      discord: "https://discord.gg/mNzpGX"
    },
    {
      name: "Living Auberean",
      type: "ACE",
      description: "PvE. Retail experience with convenience changes. Max. 3 accounts.",
      address: "63.226.232.178:9000",
      discord: "https://discord.gg/wjUbrjE"
    },
    {
      name: "Levistras",
      type: "ACE",
      description: "PvE. Retail experience. Max. 2 accounts. No botting.",
      address: "acportalstorm.com:9000",
      discord: "https://discord.gg/aD2t6Yb"
    },
    {
      name: "PotatoAC",
      type: "ACE",
      description: "PvP. Custom experience: 1.5-3x XP w/ emphasis on custom content.",
      address: "potato.ac:9000",
      discord: "https://discord.gg/R6dXBP"
    },
    {
      name: "RisingSun",
      type: "ACE",
      description: "PvE. Retail experience.",
      address: "risingsun.hopto.org:9000",
      discord: "https://discord.gg/XCXH8R8"
    },
    {
      name: "Winterthaw",
      type: "ACE",
      description: "PvE. Convenience changes and custom content.",
      address: "23.20.74.30:9000",
      website: "https://docs.google.com/spreadsheets/d/1dToIsC8l6dvJqrTloLftiUp40QSqxpNJAiPKnq8cTH4",
      discord: "https://discord.gg/mNzpGX"
    },
    {
      name: "Gloomfell",
      type: "ACE",
      description: "PvE. Increased difficulty server. Max. 2 accounts. Custom content.",
      address: "3.19.16.15:9000"
    },
    {
      name: "Thistlecrown",
      type: "ACE",
      description: "PvE. Retail experience with convenience changes.",
      address: "thistlecrown.ddns.net:9000",
      discord: "https://discord.gg/4JDxss"
    },
    {
      name: "DobZ",
      type: "ACE",
      description: "PvP. Retail experience. 3x XP.",
      address: "dobzac.ddns.net:9000",
      discord: "https://discord.gg/wPXb9P"
    },
    {
      name: "LostWoods AC",
      type: "ACE",
      description: "PvE. Retail experience w/ progressive custom content. 1x XP.",
      address: "lostwoodsac.hopto.org:9000",
      discord: "https://discord.gg/ZwQkCdx"
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
