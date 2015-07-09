class App < Sinatra::Application
  get '/chain/:server/:name?' do |server, name|
    content_type :json

    character = Character.find_by(server: server, name: name)

    return "{}" if character.nil?

    t = Chain.new(server, name)
    tree = t.get_chain

    tree.to_json
  end
end
