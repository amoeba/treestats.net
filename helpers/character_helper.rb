module CharacterHelper
  ATTRIBUTES = ["strength", "endurance", "coordination", "quickness", "focus", "self"]
  SHORT_ATTRIBUTES = { "strength" => "Str",
    "endurance" => "End",
    "coordination" => "Coord",
    "quickness" => "Quick",
    "focus" => "Focus",
    "self" => "Self"
  }

  def self.tag_html(character)
    html_strings = []
    html_strings << "<div class='tag'>" # Open up tag div

    if(character[:level])
      html_strings << "<span class='tag-level'>#{character[:level]}</span>"
    end

    if(character[:attribs])
      top_attribs = character[:attribs].find_all { |a| a[1]["creation"] == 100}.map { |a| "#{a[0]}" }

      top_attributes = ATTRIBUTES.find_all { |a| top_attribs.include?(a) }
      html_strings << top_attributes.map { |a| "<span class='tag-attribute'>#{SHORT_ATTRIBUTES[a]}</span>" }.join("")

    end


    if(character[:skills])
      html_strings << "<span class='tag-skills'>"
      # html_strings << character[:skills].find_all { |s| s[1]["training"] == "Specialized" }.map { |s| s[0]}.sort.map { |s| "<span class='tag-skill'><img src='/images/skills/#{s}.png' alt='#{s.split('_').map(&:capitalize).join(' ')}'/></span>"}.join("")
      html_strings << character[:skills].find_all { |s| s[1]["training"] == "Specialized" }.map { |s| s[0]}.sort.map { |s| "<span class='tag-skill' style='background-image: url(/images/skills/#{s}.png)''></span>"}.join("")
      html_strings << "</span>"
    end

    html_strings << "</div>" # Close tag div

    return_val = html_strings.join(" ")

    return_val
  end
end
