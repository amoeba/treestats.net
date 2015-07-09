class App < Sinatra::Application
  get '/logs/?' do
    @logs = Log.all.desc(:created_at).limit(100)

    haml :logs
  end
end
