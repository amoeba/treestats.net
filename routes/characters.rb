class App < Sinatra::Application
  get '/characters/?' do
    @characters = Character.all.limit(100).desc(:updated_at).where(:attribs.exists => true)

    haml :characters
  end
end
