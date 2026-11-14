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

            # Character counts are computed from collection metadata instead of
            # scanning: the unfiltered total comes from estimated_document_count
            # (WiredTiger metadata, O(1)) and the default-scope total is that
            # minus the tiny excluded minority (archived docs or names starting
            # with "+"), counted with the ar partial index and the n prefix
            # bounds of /^\+/. The metadata estimate can drift by a handful of
            # documents after an unclean mongod shutdown.
            estimated_total = Character.collection.estimated_document_count
            excluded = Character.collection.count_documents(
              '$or' => [{ 'ar' => true }, { 'n' => /^\+/ }]
            )

            @total_characters = estimated_total - excluded
            @total_characters_incl_filtered = estimated_total

            # distinct(:server) over the s index — index-key scan, not a
            # document scan.
            distinct_with_uploads = Character.unscoped.distinct(:server)
            unlisted_with_uploads = (distinct_with_uploads - tracked_servers).size

            @total_servers_incl_unlisted = tracked_servers.size + unlisted_with_uploads

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
