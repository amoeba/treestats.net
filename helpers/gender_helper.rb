module GenderHelper
  GENDERS = {
    1  => "Male",
    2  => "Female"
  }
  
  GENDER_ID = {
    "Male" => 1,
    "Female" => 2
  }
  
  def self.get_gender_name(id)
    GENDERS[id] ? GENDERS[id] : id
  end
  
  def self.get_gender_id(name)
    GENDER_ID[name] ? GENDER_ID[name] : name
  end
end