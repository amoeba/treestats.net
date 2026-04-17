#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Smoke-test the POST /characters bulk upload endpoint.
#
# Usage:
#   bundle exec ruby scripts/test_bulk_upload.rb [COUNT] [SERVER]
#
# Environment:
#   TS_API_KEY  API key from POST /account/key (format: ts_<account_id><secret>)
#   HOST        Host and port (default: localhost:3000)
#
# Examples:
#   bundle exec ruby scripts/test_bulk_upload.rb
#   bundle exec ruby scripts/test_bulk_upload.rb 100 TestServer
#   TS_API_KEY=ts_... bundle exec ruby scripts/test_bulk_upload.rb 500
#
# To generate a key:
#   curl -s -X POST http://localhost:3000/account/key \
#     -H 'Content-Type: application/json' \
#     -d '{"name":"myaccount","password":"mypassword"}'

require "bundler/setup"
require "net/http"
require "json"
require "openssl"

COUNT   = (ARGV[0] || 10).to_i
SERVER  = ARGV[1] || "TestServer"
HOST    = ENV.fetch("HOST", "localhost:3000")
API_KEY = ENV["TS_API_KEY"]

unless API_KEY
  warn "Error: TS_API_KEY must be set."
  warn "Generate a key with:"
  warn "  curl -s -X POST http://#{HOST}/account/key \\"
  warn "    -H 'Content-Type: application/json' \\"
  warn "    -d '{\"name\":\"myaccount\",\"password\":\"mypassword\"}'"
  exit 1
end

body = COUNT.times.map do |i|
  {
    "name"          => "BulkTest#{i}",
    "server"        => SERVER,
    "level"         => rand(1..275),
    "race"          => rand(1..9).to_s,
    "gender"        => %w[1 2].sample,
    "total_xp"      => rand(0..10_000_000_000),
    "unassigned_xp" => rand(0..1_000_000),
  }.to_json
end.join("\n")

signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", API_KEY, body)}"

puts "Uploading #{COUNT} records to http://#{HOST}/characters …"

uri = URI("http://#{HOST}/characters")
req = Net::HTTP::Post.new(uri)
req["Content-Type"]                   = "application/x-ndjson"
req["X-TreeStats-Upload-Signature"]   = signature
req["X-TreeStats-Api-Key"]            = API_KEY
req.body = body

res = Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }

puts "HTTP Status: #{res.code}"
puts res.body
