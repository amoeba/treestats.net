class App < Sinatra::Application
  get '/stats/uploads/daily' do
    value = redis.keys "uploads.daily.*"

    result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(".")[2], :count => redis.get(v).to_i }}

    result.to_json
  end
end
