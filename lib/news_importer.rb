require 'time'

class NewsImporter
  class Error < StandardError; end

  def initialize(entries)
    @entries = entries
  end

  def validate!
    raise Error, 'Expected an array of news entries.' unless @entries.is_a?(Array)
    seen = {}
    @entries.each do |entry|
      raise Error, 'Each entry must be an object with a legacy_id.' unless entry.is_a?(Hash) && entry['legacy_id'].is_a?(String) && !entry['legacy_id'].strip.empty?
      key = entry['legacy_id']
      raise Error, "Duplicate legacy_id: #{key}" if seen[key]
      seen[key] = true
      post = build_post(entry)
      raise Error, "#{key}: #{post.errors.full_messages.join(', ')}" unless post.valid?
    end
    true
  end

  def run(dry_run: false, output: $stdout)
    validate!
    NewsPost.ensure_indexes! unless dry_run
    @entries.each do |entry|
      key = entry.fetch('legacy_id')
      if NewsPost.where(legacy_id: key).exists?
        output.puts "Skipped (already imported): #{key}"
      elsif dry_run
        output.puts "Would import: #{entry.fetch('title')}"
      else
        begin
          build_post(entry).save!
          output.puts "Imported: #{entry.fetch('title')}"
        rescue Mongo::Error::OperationFailure => error
          # A simultaneous invocation may have imported the same legacy entry.
          raise unless error.code == 11000 && NewsPost.where(legacy_id: key).exists?
          output.puts "Skipped (already imported): #{key}"
        end
      end
    end
  end

  private

  def build_post(entry)
    date = entry['published_at']
    raise Error, "#{entry['legacy_id']}: expected an ISO 8601 UTC publication date" unless date.is_a?(String) && date.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
    NewsPost.new(title: entry['title'], body: entry['body'], status: 'published',
      published_at: Time.iso8601(date), legacy_id: entry['legacy_id'])
  rescue ArgumentError => error
    raise Error, "#{entry['legacy_id']}: #{error.message}"
  end
end
