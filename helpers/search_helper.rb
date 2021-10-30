module SearchHelper
  TOKEN_SEP = ":"

  def self.process_search(query = "")
    parts = {}

    query.strip.split.each do |t|
      subtokens = t.split(TOKEN_SEP)

      if subtokens.length == 1
        parts[:name] = /#{Regexp.escape(subtokens[0].strip)}/i
      elsif subtokens.length == 2
        field = subtokens[0].strip
        value = subtokens[1].strip

        # Try to find the type
        klass = Character.fields.select { |k,v| v.options && v.options[:as] && v.options[:as].to_s == field }

        # Convert to Integer if we should or otherwise turn into regex
        if klass.length >= 1 && klass.first[1].options[:type] == Integer
          value = value.to_i
        elsif field == "gender"
          value = /\A#{Regexp.escape(value)}\Z/i
        else
          value = /#{Regexp.escape(value)}/i
        end

        # Set it
        parts[field.to_sym] = value
      end
    end

    parts
  end
end
