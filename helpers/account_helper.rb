module AccountHelper
  TABLE_FIELD_MAPPINGS = [
    { :name => "race", 
      :label => "Race", 
      :value => Proc.new { |v| v[:race] }
    },
    {
      :name => "gender", 
      :label => "Gender", 
      :value => Proc.new { |v| v[:gender] }
    },
    { 
      :name => "unassigned_xp", 
      :label => "Unassigned XP", 
      :value => Proc.new { |v| add_commas(v[:unassigned_xp].to_s) }
    },
    {  
      :name => "luminance_earned", 
      :label => "Luminance", 
      :value => Proc.new { |v| add_commas(v[:luminance_earned].to_s) }
    },
    {  
      :name => "current_title", 
      :label => "Title", 
      :value => Proc.new { |v| TitleHelper::get_title_name(v[:current_title]) }
    },
    {  
      :name => "rank", 
      :label => "Rank",
      :value => Proc.new { |v| "#{RankHelper::get_rank_name(RaceHelper::get_race_id(v[:race]), GenderHelper::get_gender_id(v[:gender]), v[:rank])} (#{v[:rank]})" }
      # :value => Proc.new { |v| "#{RaceHelper::get_race_id(v[:race])} #{GenderHelper::get_gender_id(v[:gender])} #{v[:rank]}" }
    },
    {  
      :name => "allegiance_name",
      :label => "Allegiance", 
      :value => Proc.new { |v| v[:allegiance_name] }
    },
    {  
      :name => "monarch", 
      :label => "Monarch", 
      :value => Proc.new { |v| v[:monarch] ? v[:monarch][:name] : "" }
    },
    {  
      :name => "patron",
      :label => "Patron", 
      :value => Proc.new { |v| v[:patron] ? v[:patron][:name] : "" }
    },
    { 
      :name => "vassals", 
      :label => "Vassals", 
      :value => Proc.new { |v| v[:vassals] ? v[:vassals].length : "" }
    }
  ]
  
  def self.parse_birth(birth)
    DateTime.strptime("#{birth} EST", "%m/%d/%Y %H:%M:%S %p %Z")
  end
end