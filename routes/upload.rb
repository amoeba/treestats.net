def print_and_maybe_sentry(msg)
  Sentry.capture_message(msg) if ENV["RACK_ENV"] == "production"
  puts msg
end

module Sinatra
  module TreeStats
    module Routing
      module Upload
        def self.registered(app)
          # Primary Decal-plugin endpoint; uses the configured body verifier.
          app.post '/' do
            process_character_upload(token_required: false)
          end

          # Direct server uploads require a server-scoped upload token.
          app.post '/characters/?' do
            process_character_upload(token_required: true)
          end
        end
      end
    end
  end
end
