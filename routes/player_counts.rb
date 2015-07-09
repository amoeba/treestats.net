class App < Sinatra::Application
  get '/player_counts/?' do
    haml :player_counts
  end

  get '/player_counts.json' do
    content_type :json

    response = {}

    player_counts = PlayerCount.all.sort(server: 1, created_at: 1)

    # Remove _id field and respond with json
    if(player_counts.exists?)
      response = player_counts.collect { |pc| {
        :server => pc.server,
        :count => pc.count,
        :timestamp => pc.created_at
      }}.to_json
    end

    response
  end
end
