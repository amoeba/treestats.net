module Sinatra
  module TreeStats
    module Routing
      module Chain
        def self.registered(app)
          app.get '/chain/:server/:name?' do |server, name|
            content_type :json

            chain = AllegianceChain.new(server, name)
            highest_patron = chain.find_highest_patron
            not_found if highest_patron.nil?

            redis_key = "chain:#{server}:#{highest_patron}"
            cached = redis.get(redis_key)
            return cached if cached

            result = Oj.dump(chain.get_chain(highest_patron))
            redis.setex(redis_key, 300, result)
            result
          end
        end
      end
    end
  end
end
