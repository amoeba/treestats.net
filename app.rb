Dotenv.load if settings.development?

class App < Sinatra::Application
  configure do
    set :root, File.dirname(__FILE__)

    # Mongoid
    Mongoid.load!("./config/mongoid.yml")

    # Rollbar
    if settings.production?
      Rollbar.configure do |config|
        config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
      end
    end
  end  
end

Dir["./helpers/*.rb"].each { |file| require file }
Dir["./models/*.rb"].each { |file| require file }
Dir["./routes/*.rb"].each { |file| require file }