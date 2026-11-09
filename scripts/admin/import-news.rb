#!/usr/bin/env ruby
# This is an explicit operator action, never part of startup or deployment.
require 'optparse'
require 'json'
require_relative '../../lib/news_importer'

options = {apply: false, file: File.expand_path('../../data/legacy_news.json', __dir__)}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: bundle exec ruby scripts/admin/import-news.rb [--dry-run | --apply] [--file PATH]'
  opts.on('--dry-run', 'Report only (the default); do not write posts or indexes') { options[:apply] = false }
  opts.on('--apply', 'Import historical news into the configured database') { options[:apply] = true }
  opts.on('--file PATH', 'Use an alternative JSON dataset') { |path| options[:file] = File.expand_path(path) }
  opts.on('-h', '--help', 'Show usage') { puts opts; exit }
end

begin
  parser.parse!
  raise OptionParser::InvalidArgument, ARGV.join(' ') unless ARGV.empty?
  entries = JSON.parse(File.read(options[:file]))
  Dir.chdir(File.expand_path('../..', __dir__)) do
    require_relative '../../app'
    puts "News import: #{ENV.fetch('RACK_ENV', 'development')} (#{options[:apply] ? 'APPLY' : 'DRY RUN — no writes'})"
    NewsImporter.new(entries).run(dry_run: !options[:apply])
  end
rescue OptionParser::ParseError, JSON::ParserError, Errno::ENOENT => error
  warn error.message
  warn parser
  exit 1
rescue NewsImporter::Error => error
  warn "Import aborted: #{error.message}"
  exit 1
end
