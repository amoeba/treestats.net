# Helpers for the app
module AppHelper
  @legacy_servers = %w{Darktide Frostfell Harvestgain Leafcull Morningthaw Thistledown Solclaim Verdantine WintersEbb}
  @gdle_servers = %w{Reefcull Hightide Harvestbud}
  @ace_servers = %w{Coldeve RIPtide PotatoAC Levistras Drunkenfell Shadowgain Ragnarok}

  def self.all_servers
    @legacy_servers + @gdle_servers + @ace_servers
  end

  def self.retail_servers
    @legacy_servers
  end

  def self.servers
    @gdle_servers + @ace_servers
  end

  def self.add_commas(string)
    string.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def self.nice_date(time)
    diff = (Time.now - time).to_i

    minutes, seconds = diff.divmod(60)
    hours, minutes = minutes.divmod(60)
    days, hours   = hours.divmod(24)
    years, days = days.divmod(365)

    tmp = ""
    tokens = []

    if(years > 0)
      tmp = years.to_s
      tmp += years == 1 ? " year" : " years"

      tokens.push(tmp)
    end

    if(days > 0)
      tmp = days.to_s
      tmp += days == 1 ? " day" : " days"

      tokens.push(tmp)
    end

    if(hours > 0)
      tmp = hours.to_s
      tmp += hours == 1 ? " hour" : " hours"

      tokens.push(tmp)
    end

    if(minutes > 0)
      tmp = minutes.to_s
      tmp += minutes == 1 ? " minute" : " minutes"

      tokens.push(tmp)
    end

    if(seconds > 0)
      tmp = seconds.to_s
      tmp += seconds == 1 ? " second" : " seconds"

      tokens.push(tmp)
    end

    tokens.push("ago")
    tokens.join(" ")
  end

  def self.relative_time(time)
    a = (Time.now - time).to_i

    case a
      when 0 then 'just now'
      when 1 then 'a second ago'
      when 2..59 then a.to_s+' seconds ago'
      when 60..119 then 'a minute ago' #120 = 2 minutes
      when 120..3540 then (a/60).to_i.to_s+' minutes ago'
      when 3541..7100 then 'an hour ago' # 3600 = 1 hour
      when 7101..82800 then ((a+99)/3600).to_i.to_s+' hours ago'
      when 82801..172000 then 'a day ago' # 86400 = 1 day
      when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+' days ago'
      when 518400..1036800 then 'a week ago'
      else ((a+180000)/(60*60*24*7)).to_i.to_s+' weeks ago'
    end
  end
end
