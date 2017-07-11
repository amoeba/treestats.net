module Sinatra
  module TreeStats
    module Routing
      module Upload
        def self.registered(app)
          app.post '/' do
            text = request.body.read
            puts text
            return if text.length <= 0

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
            print(json_text)
            # Remove verification key if it exists
            if (json_text.has_key?("key"))
              json_text = json_text.tap { |h| h.delete("key") }
            end

            # Get the version number out and use it to let the user know to update
            # their plugin

            # version_number = json_text["version"]

            version_message = nil

            # if(version_number == "1") # Version num is a string (accepts 1.2, etc)
            #   version_message = "You're using an old version of TreeStats. " \
            #   "The latest version provides bug fixes and adds TreeStats Accounts, " \
            #   "which let you view all of your characters across accounts. " \
            #   "Please go to treestats.net and get the latest version."
            # end

            # Extract information for later in this method
            name = json_text['name']
            server = json_text['server']
            server_pop = json_text['server_population']
            allegiance_name = json_text['allegiance_name']

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

            # Log extra debug info if birth ends up being nil
            if json_text["birth"].nil? && ENV['RACK_ENV'] != 'test'
              puts "Failed to parse birth field with the following JSON..."
              puts json_text
            end

            character = Character.find_or_create_by(name: name, server: server)

            # Assign attributes then touch
            # We do this instead of just using update_attributes
            # because I'd like to update timestamps even when the character
            # update contains no new information.

            character.assign_attributes(json_text)

            # Removed archived flag
            character[:archived] = false if character[:archived]

            character.save
            character.touch


            # Update statistics
            redis.incr "uploads:daily:#{Time.now.utc.strftime("%Y%m%d")}"
            redis.incr "uploads:monthly:#{Time.now.utc.strftime("%Y%m")}"

            # ALLEGIANCE
            Allegiance.find_or_create_by(server: server, name: allegiance_name)

            # RESPONSE
            response_text = ""

            if(character.valid?)
              response_text = "Character was updated successfully."
            else
              if ENV['RACK_ENV'] != 'test'
                puts 'Character updated failed...'
                puts json_text
              end

              response_text = "Character update failed."
            end

            # Add version_text to response text
            response_text = [response_text, version_message].join(" ") if version_message

            # Return final response
            response_text
          end

          app.post '/message' do
            return "Got your message!"
          end
        end
      end
    end
  end
end
