class App
  post '/' do
    text = request.body.read

    # VERIFY
    # Before we do anything, verify the message wasn't tampered with
    if settings.production?
      verify = Encryption::decrypt(text)

      if(!verify)
        Log.create(title: "Failed to verify update", message: text)

        return "Failed to verify character update. Character was not saved."
      end
    end

    # PARSE
    # Parse message
    json_text = JSON.parse(text)

    # Remove verification key if it exists
    if (json_text.has_key?("key"))
      json_text = json_text.tap { |h| h.delete("key") }
    end

    # Extract information for later in this method
    name = json_text['name']
    server = json_text['server']
    server_pop = json_text['server_population']
    allegiance_name = json_text['allegiance_name']

    # LOGS
    # Check in the update
    Log.create(title: "/", message: text)

    # PLAYER COUNTS
    # Only save a PlayerCount if this message contains one
    if(json_text.has_key?("server_population"))
      json_text = json_text.tap { |h| h.delete('server_population')}
      PlayerCount.create(server: server, count: server_pop)
    end

    # CHARACTER

    # Convert "birth" field so it's stored as DateTime with GMT-5
    if(json_text.has_key?("birth"))
      json_text["birth"] = CharacterHelper::parse_birth(json_text["birth"])
    end

    character = Character.find_or_create_by(name: name, server: server)

    # Assign attributes then touch
    # We do this instead of just using update_attributes
    # because I'd like to update timestamps even when the character
    # update contains no new information.

    character.assign_attributes(json_text)
    character.save
    character.touch

    # Update statistics
    redis.incr "uploads:daily:#{Time.now.utc.strftime("%Y%m%d")}"
    redis.incr "uploads:monthly:#{Time.now.utc.strftime("%Y%m")}"

    # ALLEGIANCE
    Allegiance.find_or_create_by(server: server, name: allegiance_name)

    # RESPONSE
    if(character.valid?)
      return "Character was updated successfully."
    else
      MailHelper::send("Character update failed!", "<p>Raw Text<br/>#{text}</p> <p>JSON Text<br/>#{json_text}</p>")
      return "Character update failed."
    end
  end
end
