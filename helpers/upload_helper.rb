require "digest"

module UploadHelper
  # Character payloads are a few KB; anything this large is a bug or abuse.
  MAX_UPLOAD_BYTES = 1024 * 1024

  def self.validate(text)
    return false if text.nil? or text.length <= 0

    secret = ENV["TREESTATS_SECRET"]
    return true if secret.nil?

    result = false

    begin
      l = eval "lambda { |x| #{secret} }"
    rescue SyntaxError => e
      # Allow uploads on eval exception
      puts "UploadHelper.validate: Eval failed, passing upload."

      return true
    end

    begin
      result = l.call(text)
    rescue => e
      # Allow uploads on call exception
      puts "UploadHelper.validate: Call failed, passing upload."

      return true
    end

    # TODO: Ensure we're boolean

    result
  end

  def process_character_upload(token_required:)
    if request.content_length.to_i > MAX_UPLOAD_BYTES
      status 413
      return "Upload too large."
    end

    server_token = request.env[ServerAuthTokenHelper::RACK_HEADER].to_s
    if token_required && server_token.empty?
      status 401
      return "Server upload token is required."
    end

    request.body.rewind
    # Read one byte past the limit so chunked bodies (no Content-Length) are capped too.
    text = request.body.read(MAX_UPLOAD_BYTES + 1)
    return if text.empty?

    if text.bytesize > MAX_UPLOAD_BYTES
      status 413
      return "Upload too large."
    end

    unless token_required
      # Legacy plugin uploads authenticate their signed request body.
      valid = UploadHelper.validate(text)
      if !valid
        status 403

        print_and_maybe_sentry("Failed to verify character upload.")

        return "Failed to verify character update. Character was not saved."
      end
    end

    begin
      json_text = JSON.parse(text)
    rescue JSON::ParserError
      status 400
      print_and_maybe_sentry("Upload failed due to JSON parse exception")

      return "Upload failed for an unknown reason. Please report this as a bug at https://github.com/amoeba/treestats."
    end

    unless json_text.is_a?(Hash)
      status 400
      print_and_maybe_sentry("Upload payload is not a JSON object.")

      return "Upload payload must be a JSON object."
    end

    begin
      upload = UploadPayload.sanitize(json_text)
    rescue UploadPayload::Invalid => e
      status 400
      return "Invalid upload payload: #{e}."
    end

    raw_payload = json_text
    json_text = upload.payload

    if token_required
      unless ServerAuthTokenHelper.authenticate(json_text['server'], server_token)
        status 403
        return "Failed to verify server upload token. Character was not saved."
      end

      rate_limit = ServerAuthTokenHelper.record_request!(redis, server_token)
      ServerAuthTokenHelper.apply_rate_limit_headers(headers, rate_limit)
      if rate_limit[:count] > ServerAuthTokenHelper::RATE_LIMIT_MAX
        status 429
        return "Server upload rate limit exceeded. Please try again later."
      end
    end

    # Disallow uploads from retail servers
    if AppHelper.retail_servers.include?(json_text['server'])
      status 403
      print_and_maybe_sentry("Upload of characters from retail servers blocked.")

      return "Not allowed."
    end

    sample = UploadSampling.sample(raw_payload) if !token_required && ENV["RACK_ENV"] == "production"

    # Extract information for later in this method
    name = json_text['name']
    server = json_text['server']
    allegiance_name = json_text['allegiance_name']

    # PlayerCount
    # Only save a PlayerCount if this message contains one.
    # No source field: an absent source is the compact plugin default.
    PlayerCount.create(server: server, count: upload.population) if upload.population

    # Character
    # Convert "birth" field so it's stored as DateTime with GMT-5
    if(json_text.has_key?("birth"))
      json_text["birth"] = CharacterHelper::parse_birth(json_text["birth"])
    end

    # Log extra debug info if birth ends up being nil
    if json_text["birth"].nil? && ENV['RACK_ENV'] != 'test'
      print_and_maybe_sentry("Failed to parse birth field in character upload.")
    end

    # Maybe temporary maybe not: Reject updates from that have
    # patron.name set to ??
    #
    # e.g.
    #   "patron" => {"name" => "??", "race" => 11, "rank" => 4, "gender" => 1}
    #
    # I've only seen this on Whiting so far with one account / machine
    begin
      if json_text["patron"]["name"] == "??"
        status 400

        print_and_maybe_sentry("Character update failed due to \"??\" patron bug.")

        return "Malformed patron name. Ignoring your update."
      end
    rescue
      # And just continue
    end

    character = Character.unscoped.find_or_create_by(name: name, server: server)

    # Assign attributes then touch
    # We do this instead of just using update_attributes
    # because I'd like to update timestamps even when the character
    # update contains no new information.
    character.assign_attributes(json_text)

    # Removed archived flag
    character[:archived] = false if character[:archived]

    # Remove location if it wasnt sent (i.e., the user disabled it after initially sending it)
    if !json_text["location"]
      character.location = nil
    end

    # Remove monarch, patron, vassal if necessary
    if !json_text["monarch"]
      character.monarch = nil
    end

    if !json_text["patron"]
      character.patron = nil
    end

    if !json_text["vassals"]
      character.vassals = nil
    end

    # Provenance of the most recent upload, set after assign_attributes so a
    # payload cannot claim its own source. nil means the plugin.
    character[:us] = token_required ? Character::SERVER_SOURCE : nil

    # IP Address
    # Plugin uploads originate from the player's machine, so request.ip is the
    # player's address. Direct server uploads speak for many players, so the
    # caller's address is the game server and must not overwrite a player IP.
    character.ip = request.ip unless token_required

    character.save
    character.touch

    # Allegiance
    Allegiance.find_or_create_by(server: server, name: allegiance_name)

    # Statistics
    redis.incr "uploads:daily:#{Time.now.utc.strftime("%Y%m%d")}"
    redis.incr "uploads:monthly:#{Time.now.utc.strftime("%Y%m")}"

    if(character.valid?)
      UploadSampling.capture(sample) if sample
      "Character was updated successfully."
    else
      status 400

      if ENV['RACK_ENV'] != 'test'
        puts 'Character updated failed...'
      end

      if name == ""
        "Level 1 characters can't be uploaded with PhatAC currently. Sorry!"
      else
        "Character update failed."
      end
    end
  end
end
