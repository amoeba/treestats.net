module Sinatra
  module TreeStats
    module Routing
      module Stats
        def self.registered(app)
          app.get '/stats/uploads/daily' do
            value = redis.keys "uploads:daily:*"

            result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(":")[2], :count => redis.get(v).to_i }}

            # Trim last result
            result = result[0..(result.size - 2)] if result.size > 1
            result.to_json
          end

          app.get '/stats/uploads/monthly' do
            value = redis.keys "uploads:monthly:*"

            result = value.sort { |a,b| a <=> b }.map { |v| { :date => v.split(":")[2], :count => redis.get(v).to_i }}
            result.to_json
          end

          app.get '/stats/attributes' do
            Marshal.restore(redis.get("stats:attributes"))
          end

          app.get '/stats/genders' do
            Marshal.restore(redis.get("stats:genders"))
          end

          app.get '/stats/ranks' do
            Marshal.restore(redis.get("stats:ranks"))
          end

          app.get '/stats/levels' do
            Marshal.restore(redis.get("stats:levels"))
          end

          app.get '/stats/heritage' do
            Marshal.restore(redis.get("stats:heritage"))
          end

          app.get '/stats/builds' do
            Marshal.restore(redis.get("stats:builds"))
          end
        end
      end
    end
  end
end
