class App < Sinatra::Application
  get "/servers/?" do
    haml :servers
  end

  get '/:server/?' do |server|
    @characters = Character.where(server: server).limit(100).desc(:updated_at).where(:attribs.exists => true)

    haml :server
  end

  get '/:server/:name.json' do |s,n|
    @character = Character.find_by(server: s, name: n)

    response = ""

    if @character
      response = @character.as_document.tap {|h| h.delete("_id")}.to_json
    end

    response.to_json
  end

  get '/:server/:name/?' do |s,n|
    @character = Character.find_by(server: s, name: n)

    haml :character
  end
end
