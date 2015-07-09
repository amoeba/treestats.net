class App < Sinatra::Application
  not_found do
    haml :not_found
  end

  get '/' do
    haml :index
  end

  get "/download/?" do
    haml :download
  end
end
