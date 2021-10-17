module DateHelper

  def self.ensure_century(date)
    adjustment = (date.year < 1999) ? 2000 : 0
    date + adjustment.years
  end

end
