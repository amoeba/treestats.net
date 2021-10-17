module DateHelper

  FORMATS = [
    "%m/%d/%Y %H:%M:%S %p %Z",
    "%m/%d/%Y %H:%M:%S %Z"
  ]

  def self.ensure_century(date)
    adjustment = (date.year < 1999) ? 2000 : 0
    date + adjustment.years
  end

  def self.parse(date_string)
    results = FORMATS.lazy.map do |format|
      begin
        parsed = DateTime.strptime("#{date_string} EST", format)
        ensure_century(parsed)
      rescue ArgumentError
        puts "ArgumentError caught trying to parse '#{date_string} EST' as a DateTime with format #{format}"
        puts "Error was `#{$!}`"
      end
    end

    results.detect { |date| !date.nil? }
  end

end
