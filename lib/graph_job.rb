require 'resque'
require 'resque/errors'
require 'redis'

class GraphJob
  @queue = :default
  @key = "pc:max:lastrun"

  def self.perform
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    @redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    now = Time.now.utc
    boyd = now - 86400 # A day of seconds: 60 * 60 * 24

    last_run = @redis.get(@key)

    if last_run.nil?
      records = self.get_records_after(nil)
    else
      last_run_boyd = Time.utc(last_run[0,4].to_i, last_run[4,2].to_i, last_run[6,2].to_i)
      records = self.get_records_after(last_run_boyd)
    end

    return if records.count == 0

    counts = self.collect_counts(records)
    self.set_keys(counts)

    @redis.set(@key, boyd.strftime("%Y%m%d"))
  end

  def self.get_records_after(boyd)
    records = PlayerCount.without(:_id)

    if !boyd.nil?
      records = records.where({ :created_at => { "$gte" => boyd } })
    end

    records.sort(created_at: 1)
  end


  def self.collect_counts(records)
    result = {}

    records.each do |r|
      server = r['server'].downcase
      date = r['created_at'].strftime("%Y%m%d")

      result[server] ||= {}
      result[server][date] ||= []

      result[server][date] << r['count'].to_i
    end

    result
  end

  def self.set_keys(result)
    result.each do |server,_|
      result[server].each do |date,_|
        key = "pc:max:#{server}:#{date}"
        counts = result[server][date]
        value = counts.max

        @redis.set(key, value)
      end
    end
  end
end
