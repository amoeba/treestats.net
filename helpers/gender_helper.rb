module GenderHelper
  GENDERS = {
    0  => "Male",
    1  => "Female"
  }
  
  GENDER_ID = {
    "Male" => 0,
    "Female" => 1
  }
  
  def self.get_gender_name(id)
    GENDERS[id] ? GENDERS[id] : id
  end
  
  def self.get_gender_id(name)
    GENDER_ID[name] ? GENDER_ID[name] : name
  end
end