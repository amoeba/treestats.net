module ServerHelper
  @retail_servers = %w[Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb]

  @softwares = {
    "GDLE" => "https://www.gdleac.com",
    "ACE" => "https://emulator.ac",
    "ACE-Classic" => "https://github.com/Advan-tage/ACEclassic"
  }

  # Load servers data if available, otherwise use empty array
  begin
    require_relative "../data/servers"
    @servers = SERVERS
  rescue LoadError
    @servers = []
  end

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
      count = counts.find { |count| server[:name] == count[:server] }

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
