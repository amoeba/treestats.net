module CharacterHelper
  def self.parse_birth(birth)
    DateTime.strptime("#{birth} EST", "%m/%d/%Y %H:%M:%S %p %Z")
  end
end