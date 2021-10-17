module DateHelper

  def self.ensure_century(date)
    return if date.nil?

    adjustment = (date.year < 1999) ? 2000 : 0
    date + adjustment.years
  end

  def self.parse(date_string)
    parsed = nil

    # Try our first format
    begin
      parsed = DateTime.strptime("#{date_string} EST", "%m/%d/%Y %H:%M:%S %p %Z")
    rescue ArgumentError
      puts "ArgumentError caught trying to parse '#{date_string} EST' as a DateTime with format %m/%d/%Y %H:%M:%S %p %Z"
      puts "Error was `#{$!}`"
    end

    # Try our second one
    if parsed.nil?
      begin
        parsed = DateTime.strptime("#{date_string} EST", "%m/%d/%Y %H:%M:%S %Z")
      rescue ArgumentError
        puts "ArgumentError caught trying to parse '#{date_string} EST' as a DateTime with format %m/%d/%Y %H:%M:%S %Z"
        puts "Error was `#{$!}`"
      end
    end

    ensure_century(parsed)
  end

end
