module GenderHelper
  GENDERS = {
    0  => "Male",
    1  => "Female"
  }
  
  def self.get_gender_name(id)
    GENDERS[id] ? GENDERS[id] : id
  end
end