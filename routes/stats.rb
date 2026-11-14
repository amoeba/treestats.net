module Sinatra
  module TreeStats
    module Routing
      module Stats
        def self.registered(app)
          app.get '/stats' do
            # Total uploads, from the redis counters incremented on each
            # upload. The monthly counters exist since July 2015 and are far
            # fewer keys to sum than the daily ones (both are incremented
            # together, so the sums agree).
            keys = redis.keys("uploads:monthly:*")
            @total_uploads = keys.empty? ? 0 : redis.mget(keys).sum { |v| v.to_i }

            tracked_servers = ServerHelper.all_servers
            @total_servers = tracked_servers.size

            # Mongo counts are expensive; cache them briefly like the other
            # dashboard aggregates. v3: server cards are now total vs. total
            # including unlisted (uploads from servers not on the tracked list).
            cache_key = "stats-page-counts:v3"
            counts = if redis.exists?(cache_key)
              Marshal.restore(redis.get(cache_key))
            else
              distinct_with_uploads = Character.unscoped.distinct(:server)
              unlisted_with_uploads = (distinct_with_uploads - tracked_servers).size

              fresh = {
                :total_servers_incl_unlisted => tracked_servers.size + unlisted_with_uploads,
                :total_characters => Character.count,
                :total_characters_incl_filtered => Character.unscoped.count
              }
              redis.setex(cache_key, 300, Marshal.dump(fresh))
              fresh
            end

            @total_servers_incl_unlisted = counts[:total_servers_incl_unlisted]
            @total_characters = counts[:total_characters]
            @total_characters_incl_filtered = counts[:total_characters_incl_filtered]

            haml :stats
          end

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

          app.get '/stats/levelfreq' do
              Marshal.restore(redis.get("stats:levelfreq"))
          end
        end
      end
    end
  end
end
