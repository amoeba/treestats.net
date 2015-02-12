# Helpers for the app

def add_commas(string)
  string.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def nice_date(time)
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