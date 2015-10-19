require 'resque'
require 'resque/errors'
require 'redis'

class GraphWorker
  @queue = :default
  @key = "pc:mean:lastrun"

  def self.perform
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    uri = URI.parse(redis_url)
    @redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    now = DateTime.now
    boyd = DateTime.new(now.year, now.month, now.day - 1)

    last_run = @redis.get(@key)

    if last_run.nil?
      records = self.get_records_after(nil)
    else
      last_run_boyd = DateTime.new(last_run[0,4].to_i, last_run[4,2].to_i, last_run[6,2].to_i)
      records = self.get_records_after(last_run_boyd)
    end

    return if records.count == 0

    means = self.calculate_daily_means(records)
    self.set_keys(means)

    @redis.set(@key, boyd.strftime("%Y%m%d"))
  end

  def self.get_records_after(boyd)
    records = PlayerCount.without(:_id)

    if !boyd.nil?
      records = records.where({ :created_at => { "$gte" => boyd } })
    end

    records.sort(created_at: 1)
  end


  def self.calculate_daily_means(records)
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
        key = "pc:mean:#{server}:#{date}"
        counts = result[server][date]
        mean = counts.inject { |sum,el| sum + el }.to_f / counts.size

        @redis.set(key, mean)
      end
    end
  end

  def self.flush(str)
    puts str
    $stdout.flush
  end
end
