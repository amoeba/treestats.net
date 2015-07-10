class App < Sinatra::Application
  get '/characters/?' do
    @characters = Character.all.limit(100).desc(:updated_at).where(:attribs.exists => true)

    haml :characters
  end

  get '/:server/:name.json' do |s,n|
    @character = Character.find_by(server: s, name: n)
    @character = @character.as_document.tap {|h| h.delete("_id")}

    content_type 'application/json'
    JSON.pretty_generate(@character)
  end

  get '/:server/:name/?' do |s,n|
    @character = Character.find_by(server: s, name: n)

    haml :character
  end
end
