require 'dotenv'
Dotenv.load
Dir["./helpers/*.rb"].each { |file| require file }
Dir["./models/*.rb"].each { |file| require file }
Dir["./routes/*.rb"].each { |file| require file }

class App < Sinatra::Application
  configure do
    set :root, File.dirname(__FILE__)

    # Mongoid
    Mongoid.load!("./config/mongoid.yml")
  end
end
