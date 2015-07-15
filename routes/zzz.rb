class App < Sinatra::Application
  # get '/:server/:name.json' do |s,n|
  #   begin
  #     @character = Character.find_by(server: s, name: n)
  #   rescue Mongoid::Errors::DocumentNotFound
  #     not_found
  #   end

  #   content_type 'application/json'
  #   JSON.pretty_generate(@character.serializable_hash({}).tap {|h| h.delete("id")})
  # end

  # get '/:server/:name/?' do |s,n|
  #   begin
  #     @character = Character.find_by(server: s, name: n)
  #   rescue Mongoid::Errors::DocumentNotFound
  #     not_found
  #   end

  #   haml :character
  # end  
end