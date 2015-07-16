class App
  get "/servers/?" do
    haml :servers
  end

  get '/:server/?' do |server|
    @characters = Character.where(server: server).limit(100).desc(:updated_at).where(:attribs.exists => true)

    haml :server
  end
end
