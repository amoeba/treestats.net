#!/usr/bin/env ruby
# frozen_string_literal: true
#
# End-to-end test for the bulk upload feature.
#
# Starts sidekiq if not running, exercises every code path, waits for Sidekiq
# to finish, then queries MongoDB directly to verify the right characters
# landed in the database.
#
# Usage:
#   bundle exec ruby scripts/e2e_bulk_upload.rb
#
# Environment:
#   HOST      Host and port (default: localhost:3000)
#   ACCOUNT   Test account name (default: BulkE Two E)
#   PASSWORD  Test account password (default: e2epassword)

require "bundler/setup"
require "net/http"
require "json"
require "openssl"
require "securerandom"
require "base64"
require "set"
require "optparse"
require "sidekiq/api"

# ── configuration ──────────────────────────────────────────────────────────────

DEFAULT_HOST = "localhost:3000"
ACCOUNT = "BulkE Two E"
PASSWORD = "e2epassword"
DEFAULT_ALLEGIANCE_SERVER = "Testfall"
DEFAULT_ALLEGIANCE_NAME = "Test Suite"
DEFAULT_FLAT_UPLOAD_SIZE = 1000
DEFAULT_TREE_SIZE = 1000
DEFAULT_VASSALS_PER_PATRON = 10
ENV["RACK_ENV"] = "development"
RACK_ENV = ENV["RACK_ENV"]

# ── output helpers ─────────────────────────────────────────────────────────────

BOLD  = "\e[1m"
GREEN = "\e[0;32m"
RED   = "\e[0;31m"
DIM   = "\e[2m"
YELL  = "\e[0;33m"
RESET = "\e[0m"

def bold(msg)   = puts("#{BOLD}#{msg}#{RESET}")
def green(msg)  = puts("#{GREEN}#{msg}#{RESET}")
def red(msg)    = puts("#{RED}#{msg}#{RESET}")
def dim(msg)    = puts("#{DIM}#{msg}#{RESET}")
def yellow(msg) = puts("#{YELL}#{msg}#{RESET}")

$pass = 0
$fail = 0

def pass(label) = ($pass += 1; green("  \u2713 #{label}"))
def fail_check(label) = ($fail += 1; red("  \u2717 #{label}"))
def abort!(msg) = (red("FATAL: #{msg}"); exit(1))

def help_text
  <<~HELP
    Usage:
      ruby scripts/e2e_bulk_upload.rb --mode flat
      ruby scripts/e2e_bulk_upload.rb --mode tree

    Optional flags:
      --clean                       Delete all existing characters and allegiances before the run
      --host HOST                   App host and port, default #{DEFAULT_HOST}
      --mode MODE                   Fixture mode: flat or tree
      --size N                      Record count, default #{DEFAULT_FLAT_UPLOAD_SIZE} for flat and #{DEFAULT_TREE_SIZE} for tree
      --vassals-per-patron N        Maximum tree branching factor, default #{DEFAULT_VASSALS_PER_PATRON}
      -h, --help                    Show this help text

    Notes:
      Bare execution is disabled. You must pass --mode.
      In tree mode, VASSALS_PER_PATRON is a maximum branching factor. The last level may be partially filled.

    Examples:
      ruby scripts/e2e_bulk_upload.rb --mode flat
      ruby scripts/e2e_bulk_upload.rb --clean --mode tree
      ruby scripts/e2e_bulk_upload.rb --host staging.local:3000 --mode flat
      ruby scripts/e2e_bulk_upload.rb --mode tree
      ruby scripts/e2e_bulk_upload.rb --mode tree --size 1093 --vassals-per-patron 3
  HELP
end

def parse_options!
  options = {
    clean: false,
    host: DEFAULT_HOST,
    mode: nil,
    size: nil,
    vassals_per_patron: DEFAULT_VASSALS_PER_PATRON
  }

  parser = OptionParser.new do |opts|
    opts.banner = help_text

    opts.on("--clean", "Delete all existing characters and allegiances before the run") do
      options[:clean] = true
    end

    opts.on("--host HOST", "App host and port") do |host|
      options[:host] = host
    end

    opts.on("--mode MODE", "Fixture mode: flat or tree") do |mode|
      unless %w[flat tree].include?(mode)
        raise OptionParser::InvalidArgument, "mode must be 'flat' or 'tree'"
      end

      options[:mode] = mode
    end

    opts.on("--size N", Integer, "Record count") do |size|
      options[:size] = size
    end

    opts.on("--vassals-per-patron N", Integer, "Exact tree branching factor") do |count|
      options[:vassals_per_patron] = count
    end

    opts.on("-h", "--help", "Show this help text") do
      puts help_text
      exit 0
    end
  end

  parser.parse!(ARGV)
  abort!("Unknown positional arguments: #{ARGV.join(' ')}\n\n#{help_text}") if ARGV.any?
  unless options[:mode]
    puts help_text
    exit 1
  end
  options[:size] ||= options[:mode] == "flat" ? DEFAULT_FLAT_UPLOAD_SIZE : DEFAULT_TREE_SIZE

  options
rescue OptionParser::ParseError => e
  abort!("#{e.message}\n\n#{help_text}")
end

def ensure_safe_rack_env!
  abort!("Refusing to run e2e bulk upload in production") if RACK_ENV == "production"
  abort!("e2e bulk upload must force RACK_ENV to 'development'") unless RACK_ENV == "development"
end

# ── HTTP helpers ───────────────────────────────────────────────────────────────

def http_get(path, headers: {})
  uri = URI.join(BASE_URI.to_s + "/", path.delete_prefix("/"))
  req = Net::HTTP::Get.new(uri)
  headers.each { |k, v| req[k] = v }

  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = 10
  http.request(req)
rescue => e
  abort!("HTTP request to #{path} failed: #{e}")
end

def http_post(path, body: nil, headers: {})
  uri = URI.join(BASE_URI.to_s + "/", path.delete_prefix("/"))
  req = Net::HTTP::Post.new(uri)
  headers.each { |k, v| req[k] = v }
  req.body = body if body

  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = 10
  http.request(req)
rescue => e
  abort!("HTTP request to #{path} failed: #{e}")
end

def check_status(label, response, expected)
  got = response.code.to_i
  if got == expected
    pass("#{label} → HTTP #{got}")
  else
    fail_check("#{label} → expected HTTP #{expected}, got HTTP #{got}  body=#{response.body.inspect}")
  end
end

def check_json(label, response, field, expected)
  body = JSON.parse(response.body) rescue {}
  got  = body[field.to_s]
  if got == expected
    pass("  #{label} ('#{field}' = #{got.inspect})")
  else
    fail_check("  #{label} — '#{field}': expected #{expected.inspect}, got #{got.inspect}")
  end
end

# ── signing ────────────────────────────────────────────────────────────────────

def sign(key, body)
  OpenSSL::HMAC.hexdigest("SHA256", key, body)
end

def env_int(name, default)
  Integer(ENV.fetch(name, default.to_s), 10)
rescue ArgumentError
  abort!("#{name} must be an integer")
end

def build_allegiance_tree_records(server:, allegiance_name:, total_nodes:, vassals_per_patron:)
  abort!("ALLEGIANCE_SIZE must be >= 1") if total_nodes < 1
  abort!("VASSALS_PER_PATRON must be between 1 and 10") unless (1..10).cover?(vassals_per_patron)

  races = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]
  genders = %w[1 2]
  ranks = (1..10).to_a

  nodes = total_nodes.times.map do |i|
    {
      "name" => format("TreeMember%04d", i),
      "race" => races[i % races.length],
      "gender" => genders[i % genders.length],
      "rank" => ranks[i % ranks.length],
      "parent_name" => nil,
      "child_names" => []
    }
  end

  root = nodes.first
  queue = [root]
  next_idx = 1

  while queue.any? && next_idx < nodes.length
    parent = queue.shift
    vassals_per_patron.times do
      child = nodes[next_idx]
      abort!("internal tree generation error: ran out of child nodes") if child.nil?

      child["parent_name"] = parent["name"]
      parent["child_names"] << child["name"]
      queue << child
      next_idx += 1
      break if next_idx >= nodes.length
    end
  end

  index = nodes.each_with_object({}) { |node, acc| acc[node["name"]] = node }
  monarch_ref = {
    "name" => root["name"],
    "race" => root["race"],
    "gender" => root["gender"],
    "rank" => root["rank"]
  }

  records = nodes.map do |node|
    record = {
      "server" => server,
      "name" => node["name"],
      "race" => node["race"],
      "gender" => node["gender"],
      "rank" => node["rank"],
      "allegiance_name" => allegiance_name,
      "monarch" => monarch_ref
    }

    if node["parent_name"]
      parent = index.fetch(node["parent_name"])
      record["patron"] = {
        "name" => parent["name"],
        "race" => parent["race"],
        "gender" => parent["gender"],
        "rank" => parent["rank"]
      }
    end

    if node["child_names"].any?
      record["vassals"] = node["child_names"].map do |child_name|
        child = index.fetch(child_name)
        {
          "name" => child["name"],
          "race" => child["race"],
          "gender" => child["gender"],
          "rank" => child["rank"]
        }
      end
    end

    record
  end

  {
    records: records,
    root_name: root["name"],
    name_index: records.each_with_object({}) { |record, acc| acc[record["name"]] = record }
  }
end

def traverse_tree_records(root_name, index)
  visited = Set.new
  queue = [root_name]

  until queue.empty?
    current_name = queue.shift
    next if visited.include?(current_name)

    visited << current_name
    record = index[current_name]
    next unless record && record["vassals"]

    record["vassals"].each do |vassal|
      queue << vassal["name"]
    end
  end

  visited
end

# ── rate-limit key flushing ────────────────────────────────────────────────────

def flush_rate_limit
  redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
  redis.del("bulk_upload:ratelimit:127.0.0.1")
end

def flush_inflight
  redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
  redis.del(BulkUploadHelper::INFLIGHT_KEY)
end

def flush_sidekiq_state
  cleared = 0

  Sidekiq::Queue.all.each do |queue|
    cleared += queue.size
    queue.clear
  end

  [Sidekiq::RetrySet.new, Sidekiq::ScheduledSet.new, Sidekiq::DeadSet.new].each do |set|
    set.each do |job|
      job.delete
      cleared += 1
    end
  end

  pass("Cleared Sidekiq state (#{cleared} job#{'s' if cleared != 1})")
end

def maybe_clean_db!
  return unless $cli_options[:clean]

  dim("  Cleaning existing characters and allegiances...")
  Character.unscoped.delete_all
  Allegiance.delete_all
  pass("Existing characters and allegiances removed")
end

# ── payloads ───────────────────────────────────────────────────────────────────
# Defined here so the DB-verification step can reference the exact same values.

NDJSON_RECORDS = [
  { "name" => "E Two ENdjson0", "server" => "TestServer", "level" => 50,  "race" => "1", "gender" => "1", "total_xp" => 1_000_000 },
  { "name" => "E Two ENdjson1", "server" => "TestServer", "level" => 51,  "race" => "1", "gender" => "1", "total_xp" => 2_000_000 },
  { "name" => "E Two ENdjson2", "server" => "TestServer", "level" => 52,  "race" => "1", "gender" => "1", "total_xp" => 3_000_000 },
]

JSON_RECORDS = [
  { "name" => "E Two EJson0", "server" => "TestServer", "level" => 100, "race" => "2", "gender" => "2", "total_xp" => 2_000_000 },
  { "name" => "E Two EJson1", "server" => "TestServer", "level" => 101, "race" => "2", "gender" => "2", "total_xp" => 4_000_000 },
]

SINGLE_RECORD    = { "name" => "E Two ESingle",   "server" => "TestServer", "level" => 275, "race" => "3", "gender" => "1", "total_xp" => 9_999_999_999 }
POP_RECORD       = { "name" => "E Two EPop",      "server" => "TestServer", "level" => 75,  "race" => "1", "gender" => "2", "total_xp" => 0, "server_population" => 42 }
KEYSTRIP_RECORD  = { "name" => "E Two EKeyStrip", "server" => "TestServer", "level" => 60,  "race" => "1", "gender" => "1", "total_xp" => 0, "key" => "should-not-persist" }

NDJSON_BODY    = NDJSON_RECORDS.map(&:to_json).join("\n")
JSON_BODY      = JSON_RECORDS.to_json
SINGLE_BODY    = SINGLE_RECORD.to_json
POP_BODY       = POP_RECORD.to_json
KEYSTRIP_BODY  = KEYSTRIP_RECORD.to_json

# All character names we expect to find in MongoDB after jobs run
EXPECTED_NAMES = (NDJSON_RECORDS + JSON_RECORDS + [SINGLE_RECORD, POP_RECORD, KEYSTRIP_RECORD])
                   .map { |r| r["name"] }

# Names that must NOT appear (retail-server skip and bad-patron skip)
FORBIDDEN_NAMES = %w[RetailSkip BadPatron]

# ══════════════════════════════════════════════════════════════════════════════
# TEST SUITE
# ══════════════════════════════════════════════════════════════════════════════

$cli_options = parse_options!
BASE_URI = URI("http://#{$cli_options[:host]}")

# Load app models + Mongoid only after CLI gating so --help and bare execution
# do not boot the Sinatra app.
require_relative "../app"

bold "=== Bulk Upload End-to-End Tests ==="
puts "  host:    #{BASE_URI}"
puts "  account: #{ACCOUNT}"
puts "  rack env: #{RACK_ENV}"
puts ""

# ── 0. Infrastructure ──────────────────────────────────────────────────────────

bold "0. Infrastructure"
ensure_safe_rack_env!
flush_sidekiq_state
flush_inflight
maybe_clean_db!
puts ""

# ── 1. Account setup ───────────────────────────────────────────────────────────

bold "1. Account setup"

res = http_post("/account/create",
  body: { name: ACCOUNT, password: PASSWORD }.to_json,
  headers: { "Content-Type" => "application/json" }
)

case res.body
when "Account successfully created."
  pass("Account '#{ACCOUNT}' created")
when "Account with this name already exists."
  yellow("  NOTE: account already exists — reusing it")
else
  abort!("Unexpected /account/create response: #{res.body.inspect}")
end

# Checkpoint: retrieve the key and validate its format
res = http_post("/account/key",
  body: { name: ACCOUNT, password: PASSWORD }.to_json,
  headers: { "Content-Type" => "application/json" }
)
abort!("/account/key returned HTTP #{res.code}: #{res.body}") unless res.code == "200"

API_KEY = JSON.parse(res.body)["key"]
abort!("Could not extract key from: #{res.body}") if API_KEY.nil? || API_KEY.empty?

if API_KEY.match?(/\Ats_[0-9a-f]{24}[0-9a-f]{64}\z/)
  pass("API key retrieved — correct format (ts_ + 24-char id + 64-char secret, len=#{API_KEY.length})")
else
  fail_check("API key format unexpected: '#{API_KEY[0, 20]}…' (len=#{API_KEY.length})")
end

puts ""

# ── 2. Key endpoint error paths ────────────────────────────────────────────────

bold "2. Key endpoint error paths"

res = http_post("/account/key",
  body: { name: ACCOUNT, password: "wrongpassword" }.to_json,
  headers: { "Content-Type" => "application/json" }
)
check_status("Wrong password", res, 401)
check_json("error field", res, "error", "invalid credentials")

res = http_post("/account/key",
  body: { name: ACCOUNT }.to_json,
  headers: { "Content-Type" => "application/json" }
)
check_status("Missing password field", res, 400)

res = http_post("/account/key",
  body: "not json at all",
  headers: { "Content-Type" => "application/json" }
)
check_status("Invalid JSON body", res, 400)

puts ""

# ── 3. Valid uploads ───────────────────────────────────────────────────────────

bold "3. Valid uploads (expect 202)"

flush_rate_limit  # start a fresh window so all 5 succeed

res = http_post("/characters",
  body: NDJSON_BODY,
  headers: {
    "Content-Type"                    => "application/x-ndjson",
    "X-TreeStats-Api-Key"             => API_KEY,
    "X-TreeStats-Upload-Signature"    => "sha256=#{sign(API_KEY, NDJSON_BODY)}",
  }
)
check_status("NDJSON batch (3 records)", res, 202)
check_json("body has status=queued", res, "status", "queued")

res = http_post("/characters",
  body: JSON_BODY,
  headers: {
    "Content-Type"                    => "application/json",
    "X-TreeStats-Api-Key"             => API_KEY,
    "X-TreeStats-Upload-Signature"    => "sha256=#{sign(API_KEY, JSON_BODY)}",
  }
)
check_status("JSON array (2 records)", res, 202)
check_json("body has status=queued", res, "status", "queued")

res = http_post("/characters",
  body: SINGLE_BODY,
  headers: {
    "Content-Type"                    => "application/x-ndjson",
    "X-TreeStats-Api-Key"             => API_KEY,
    "X-TreeStats-Upload-Signature"    => "sha256=#{sign(API_KEY, SINGLE_BODY)}",
  }
)
check_status("Single-record NDJSON", res, 202)

res = http_post("/characters",
  body: POP_BODY,
  headers: {
    "Content-Type"                    => "application/x-ndjson",
    "X-TreeStats-Api-Key"             => API_KEY,
    "X-TreeStats-Upload-Signature"    => "sha256=#{sign(API_KEY, POP_BODY)}",
  }
)
check_status("Record with server_population field", res, 202)

res = http_post("/characters",
  body: KEYSTRIP_BODY,
  headers: {
    "Content-Type"                    => "application/x-ndjson",
    "X-TreeStats-Api-Key"             => API_KEY,
    "X-TreeStats-Upload-Signature"    => "sha256=#{sign(API_KEY, KEYSTRIP_BODY)}",
  }
)
check_status("Record with 'key' field (job must strip it)", res, 202)

puts ""

# ── 4. Auth failures ───────────────────────────────────────────────────────────
# Auth is checked before the rate limiter, so these never consume rate-limit quota.

bold "4. Auth failures (expect 403)"

auth_body = { name: "AuthTest", server: "Coldeve", level: 1,
              race: "1", gender: "1", total_xp: 0 }.to_json
good_sig  = sign(API_KEY, auth_body)
fake_key  = "ts_#{"0" * 24}#{SecureRandom.hex(32)}"

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Upload-Signature"  => "sha256=#{good_sig}",
  }
)
check_status("Missing X-TreeStats-Api-Key header", res, 403)

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => API_KEY,
    "X-TreeStats-Upload-Signature"  => "sha256=deadbeef",
  }
)
check_status("Correct key, wrong signature", res, 403)

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => API_KEY,
    "X-TreeStats-Upload-Signature"  => "sha256=#{sign(API_KEY, 'tampered body')}",
  }
)
check_status("Signature computed over different body", res, 403)

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => fake_key,
    "X-TreeStats-Upload-Signature"  => "sha256=#{sign(fake_key, auth_body)}",
  }
)
check_status("Valid-format but unknown key", res, 403)

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => "notavalidkey",
    "X-TreeStats-Upload-Signature"  => "sha256=#{good_sig}",
  }
)
check_status("Malformed key (no ts_ prefix)", res, 403)

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => API_KEY,
    "X-TreeStats-Upload-Signature"  => "sha256=",
  }
)
check_status("Empty value after sha256= prefix", res, 403)

res = http_post("/characters",
  body: auth_body,
  headers: {
    "Content-Type"         => "application/x-ndjson",
    "X-TreeStats-Api-Key"  => API_KEY,
  }
)
check_status("Missing X-TreeStats-Upload-Signature header entirely", res, 403)

puts ""

# ── 5. Job-level silent drops ──────────────────────────────────────────────────

bold "5. Job-level skips (expect 202 from endpoint, record dropped in Sidekiq job)"

flush_rate_limit

retail_body = { name: "RetailSkip",  server: AppHelper.retail_servers.first, level: 10,
                race: "1", gender: "1", total_xp: 0 }.to_json
res = http_post("/characters",
  body: retail_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => API_KEY,
    "X-TreeStats-Upload-Signature"  => "sha256=#{sign(API_KEY, retail_body)}",
  }
)
check_status("Retail server character (dropped in job)", res, 202)

patron_body = { name: "BadPatron", server: "Coldeve", level: 20,
                race: "1", gender: "1", total_xp: 0,
                patron: { name: "??" } }.to_json
res = http_post("/characters",
  body: patron_body,
  headers: {
    "Content-Type"                  => "application/x-ndjson",
    "X-TreeStats-Api-Key"           => API_KEY,
    "X-TreeStats-Upload-Signature"  => "sha256=#{sign(API_KEY, patron_body)}",
  }
)
check_status("Malformed patron name '??' (dropped in job)", res, 202)

puts ""

# ── 6. Rate limiting ───────────────────────────────────────────────────────────

bold "6. Rate limiting (expect 429)"

flush_rate_limit

rate_body     = { name: "RateTest", server: "Coldeve", level: 1,
                  race: "1", gender: "1", total_xp: 0 }.to_json
rate_sig      = sign(API_KEY, rate_body)
rate_headers  = {
  "Content-Type"                  => "application/x-ndjson",
  "X-TreeStats-Api-Key"           => API_KEY,
  "X-TreeStats-Upload-Signature"  => "sha256=#{rate_sig}",
}
hit_429 = false

20.times do |i|
  res = http_post("/characters", body: rate_body, headers: rate_headers)
  if res.code == "429"
    hit_429 = true
    pass("Rate limit enforced after #{i + 1} request(s) in window")
    check_json("error field", res, "error", "rate limit exceeded")
    break
  end
end

fail_check("Rate limit never triggered after 20 requests") unless hit_429

puts ""

# ── 7. Wait for Sidekiq to process all queued jobs ────────────────────────────

bold "7. Waiting for Sidekiq to process queued jobs…"

max_wait = 30
waited   = 0
all_found = false

until waited >= max_wait
  found = EXPECTED_NAMES.count do |name|
    Character.unscoped.where(name: name, server: "TestServer").exists?
  end

  if found == EXPECTED_NAMES.length
    all_found = true
    break
  end

  dim("  #{found}/#{EXPECTED_NAMES.length} characters found — waiting…")
  sleep 2
  waited += 2
end

if all_found
  pass("All #{EXPECTED_NAMES.length} expected characters in DB (waited #{waited}s)")
else
  found = EXPECTED_NAMES.count { |n| Character.unscoped.where(name: n, server: "TestServer").exists? }
  fail_check("Only #{found}/#{EXPECTED_NAMES.length} characters found after #{max_wait}s")
end

puts ""

# ── 8. Database verification ───────────────────────────────────────────────────

bold "8. Database verification"

db_pass = 0
db_fail = 0

db_check = lambda do |label, ok|
  if ok
    db_pass += 1
    green("  \u2713 #{label}")
  else
    db_fail += 1
    red("  \u2717 #{label}")
  end
end

# Verify each uploaded record with field-level assertions
expected_records = [
  { name: "E Two ENdjson0", server: "TestServer", level: 50,  total_xp: 1_000_000     },
  { name: "E Two ENdjson1", server: "TestServer", level: 51,  total_xp: 2_000_000     },
  { name: "E Two ENdjson2", server: "TestServer", level: 52,  total_xp: 3_000_000     },
  { name: "E Two EJson0",   server: "TestServer", level: 100, total_xp: 2_000_000     },
  { name: "E Two EJson1",   server: "TestServer", level: 101, total_xp: 4_000_000     },
  { name: "E Two ESingle",  server: "TestServer", level: 275, total_xp: 9_999_999_999 },
  { name: "E Two EPop",     server: "TestServer", level: 75                            },
  { name: "E Two EKeyStrip",server: "TestServer", level: 60                            },
]

expected_records.each do |exp|
  char = Character.unscoped.find_by(name: exp[:name], server: exp[:server]) rescue nil
  db_check.("'#{exp[:name]}' exists in DB", !char.nil?)
  next if char.nil?

  exp.each do |field, expected_val|
    next if %i[name server].include?(field)
    actual = char[field.to_s]
    db_check.("  #{exp[:name]}: #{field} = #{expected_val}", actual == expected_val)
  end
end

# 'key' field must have been stripped before the character was saved
keystrip = Character.unscoped.find_by(name: "E Two EKeyStrip", server: "TestServer") rescue nil
db_check.("'E Two EKeyStrip': 'key' field stripped before save", keystrip&.[]("key").nil?)

# server_population=42 must have created a PlayerCount record
pc_exists = PlayerCount.where(server: "TestServer", count: 42).exists? rescue false
db_check.("PlayerCount created from server_population=42 on 'E Two EPop'", pc_exists)

# Forbidden names must NOT be in the DB
FORBIDDEN_NAMES.each do |name|
  exists = Character.unscoped.where(name: name).exists? rescue false
  db_check.("'#{name}' correctly absent (retail/bad-patron drop)", !exists)
end

puts ""
puts "  DB checks: #{db_pass} passed, #{db_fail} failed"
$fail += db_fail

puts ""

# ── 9. Large allegiance upload (30,000 partial records) ───────────────────────

bold "9. Large allegiance upload"

flush_rate_limit
flush_inflight

ALLEGIANCE_MODE           = $cli_options[:mode]
ALLEGIANCE_SERVER         = DEFAULT_ALLEGIANCE_SERVER
ALLEGIANCE_NAME           = DEFAULT_ALLEGIANCE_NAME
ALLEGIANCE_SIZE           = $cli_options[:size]
VASSALS_PER_PATRON        = $cli_options[:vassals_per_patron]

tree_fixture = nil

case ALLEGIANCE_MODE
when "flat"
  races = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]
  genders = %w[1 2]
  ranks = (1..10).to_a

  allegiance_records = DEFAULT_FLAT_UPLOAD_SIZE.times.map do |i|
    {
      "server" => ALLEGIANCE_SERVER,
      "name"   => "AllegMember#{i}",
      "race"   => races[i % races.length],
      "gender" => genders[i % genders.length],
      "rank"   => ranks[i % ranks.length],
    }
  end

  puts "  mode: flat"
  puts "  records: #{ALLEGIANCE_SIZE}"
when "tree"
  tree_fixture = build_allegiance_tree_records(
    server: ALLEGIANCE_SERVER,
    allegiance_name: ALLEGIANCE_NAME,
    total_nodes: ALLEGIANCE_SIZE,
    vassals_per_patron: VASSALS_PER_PATRON
  )
  allegiance_records = tree_fixture[:records]

  puts "  mode: tree"
  puts "  records: #{ALLEGIANCE_SIZE}"
  puts "  allegiance: #{ALLEGIANCE_NAME}"
  puts "  vassals_per_patron: #{VASSALS_PER_PATRON}"
  puts "  root: #{tree_fixture[:root_name]}"
else
  abort!("Unsupported ALLEGIANCE_MODE=#{ALLEGIANCE_MODE.inspect}; expected 'flat' or 'tree'")
end

allegiance_body = allegiance_records.map(&:to_json).join("\n")

res = http_post("/characters",
  body: allegiance_body,
  headers: {
    "Content-Type"                    => "application/x-ndjson",
    "X-TreeStats-Api-Key"             => API_KEY,
    "X-TreeStats-Upload-Signature"    => "sha256=#{sign(API_KEY, allegiance_body)}",
  }
)
check_status("#{allegiance_records.length}-record allegiance NDJSON upload", res, 202)
check_json("body has status=queued", res, "status", "queued")

allegiance_log_id = (JSON.parse(res.body)["log_id"] rescue nil)
pass("Response includes log_id") if allegiance_log_id
fail_check("Response missing log_id")  unless allegiance_log_id

puts ""

# ── 10. Audit log for allegiance upload ────────────────────────────────────────

bold "10. Audit log — waiting for allegiance job to complete…"

if allegiance_log_id
  max_wait = 120
  waited   = 0
  audit_log = nil

  until waited >= max_wait
    audit_log = BulkUploadLog.find(allegiance_log_id) rescue nil
    break if audit_log&.status == "completed" || audit_log&.status == "failed"
    dim("  status=#{audit_log&.status || "not found"} — waiting…")
    sleep 3
    waited += 3
  end

  if audit_log&.status == "completed"
    pass("Job completed (waited #{waited}s)")
    puts "  submitted:  #{audit_log.submitted_at}"
    puts "  started:    #{audit_log.started_at}"
    puts "  completed:  #{audit_log.completed_at}"
    puts "  duration:   #{audit_log.duration_ms}ms"
    puts "  records:    submitted=#{audit_log.record_count} " \
         "processed=#{audit_log.processed_count} " \
         "skipped=#{audit_log.skipped_count} " \
         "errors=#{audit_log.error_count}"

    if audit_log.record_count == allegiance_records.length
      pass("record_count matches submitted (#{allegiance_records.length})")
    else
      fail_check("record_count mismatch: expected #{allegiance_records.length}, got #{audit_log.record_count}")
    end

    if audit_log.processed_count == allegiance_records.length
      pass("all #{allegiance_records.length} records processed")
    else
      fail_check("processed_count=#{audit_log.processed_count} (expected #{allegiance_records.length})")
    end
  elsif audit_log&.status == "failed"
    fail_check("Job status=failed after #{waited}s")
  else
    fail_check("Job did not complete within #{max_wait}s (status=#{audit_log&.status || "not found"})")
  end
else
  yellow("  Skipping audit log check — no log_id from upload response")
end

puts ""

# ── 11. GET /admin/logs JSON ───────────────────────────────────────────────────

bold "11. GET /admin/logs (JSON)"

admin_user = ENV.fetch("SIDEKIQ_WEB_USERNAME", "admin")
admin_pass = ENV["SIDEKIQ_WEB_PASSWORD"]
admin_headers = { "Accept" => "application/json" }
admin_headers["Authorization"] = "Basic #{Base64.strict_encode64("#{admin_user}:#{admin_pass}")}" if admin_pass

res = http_get("/admin/logs", headers: admin_headers)
check_status("GET /admin/logs returns 200", res, 200)

if res.code == "200"
  logs = JSON.parse(res.body) rescue nil

  if logs.is_a?(Array)
    pass("Response is a JSON array (#{logs.length} entries)")

    if allegiance_log_id
      entry = logs.find { |l| l["id"] == allegiance_log_id }

      if entry
        pass("Allegiance upload log present (id=#{allegiance_log_id})")

        [
          ["status",          "completed"],
          ["record_count",    allegiance_records.length],
          ["processed_count", allegiance_records.length],
          ["skipped_count",   0],
          ["error_count",     0],
        ].each do |field, expected|
          actual = entry[field]
          if actual == expected
            pass("  #{field} = #{expected.inspect}")
          else
            fail_check("  #{field}: expected #{expected.inspect}, got #{actual.inspect}")
          end
        end

        pass("  duration_ms present") if entry["duration_ms"].is_a?(Integer)
        fail_check("  duration_ms missing or wrong type") unless entry["duration_ms"].is_a?(Integer)

        pass("  submitted_at present") if entry["submitted_at"]
        fail_check("  submitted_at missing")  unless entry["submitted_at"]
      else
        fail_check("Allegiance upload log not found in response (id=#{allegiance_log_id})")
      end
    else
      yellow("  Skipping per-entry checks — no allegiance_log_id available")
    end
  else
    fail_check("Response is not a JSON array: #{res.body[0, 200]}")
  end
end

puts ""

# ── 12. Tree-mode relationship validation ─────────────────────────────────────

if ALLEGIANCE_MODE == "tree"
  bold "12. Tree-mode relationship validation"

  rel_pass = 0
  rel_fail = 0

  rel_check = lambda do |label, ok|
    if ok
      rel_pass += 1
      green("  \u2713 #{label}")
    else
      rel_fail += 1
      red("  \u2717 #{label}")
    end
  end

  tree_names = tree_fixture[:records].map { |record| record["name"] }
  tree_name_set = tree_names.to_set
  db_records = Character.unscoped.where(server: ALLEGIANCE_SERVER, :name.in => tree_names).to_a
  db_index = db_records.each_with_object({}) { |record, acc| acc[record.name] = record }

  rel_check.("all #{tree_names.length} tree characters persisted on #{ALLEGIANCE_SERVER}", db_records.length == tree_names.length)
  rel_check.("all tree names are unique", db_index.keys.length == tree_names.length)

  allegiance = Allegiance.find_by(server: ALLEGIANCE_SERVER, name: ALLEGIANCE_NAME) rescue nil
  rel_check.("allegiance '#{ALLEGIANCE_NAME}' exists", !allegiance.nil?)

  rootless = db_records.select { |record| record.patron.nil? }
  rel_check.("exactly one root has no patron", rootless.length == 1)
  rel_check.("root matches generated root #{tree_fixture[:root_name]}", rootless.first&.name == tree_fixture[:root_name])

  db_records.each do |record|
    expected = tree_fixture[:name_index].fetch(record.name)

    rel_check.("#{record.name}: allegiance_name preserved", record.allegiance_name == ALLEGIANCE_NAME)
    rel_check.("#{record.name}: monarch points to root", record.monarch && record.monarch["name"] == tree_fixture[:root_name])

    expected_patron_name = expected.dig("patron", "name")
    actual_patron_name = record.patron && record.patron["name"]
    rel_check.("#{record.name}: patron matches expected", actual_patron_name == expected_patron_name)

    expected_vassal_names = (expected["vassals"] || []).map { |vassal| vassal["name"] }.sort
    actual_vassal_names = (record.vassals || []).map { |vassal| vassal["name"] }.sort
    rel_check.("#{record.name}: vassal names match expected", actual_vassal_names == expected_vassal_names)

    actual_vassal_names.each do |vassal_name|
      rel_check.("#{record.name}: vassal #{vassal_name} exists", tree_name_set.include?(vassal_name) && db_index.key?(vassal_name))
      reciprocal_patron = db_index[vassal_name]&.patron&.[]("name")
      rel_check.("#{record.name}: vassal #{vassal_name} reciprocates patron", reciprocal_patron == record.name)
    end

    if actual_patron_name
      rel_check.("#{record.name}: patron #{actual_patron_name} exists", tree_name_set.include?(actual_patron_name) && db_index.key?(actual_patron_name))
      reciprocal_vassals = (db_index[actual_patron_name]&.vassals || []).map { |vassal| vassal["name"] }
      rel_check.("#{record.name}: patron #{actual_patron_name} includes reciprocal vassal", reciprocal_vassals.include?(record.name))
    end
  end

  expected_reachable = traverse_tree_records(tree_fixture[:root_name], tree_fixture[:name_index])
  actual_index = db_records.each_with_object({}) do |record, acc|
    acc[record.name] = {
      "vassals" => (record.vassals || []).map { |vassal| { "name" => vassal["name"] } }
    }
  end
  actual_reachable = traverse_tree_records(tree_fixture[:root_name], actual_index)

  rel_check.("generated fixture reaches all #{tree_names.length} names", expected_reachable.length == tree_names.length)
  rel_check.("persisted tree reaches all #{tree_names.length} names", actual_reachable.length == tree_names.length)
  rel_check.("persisted connectivity matches generated connectivity", actual_reachable == expected_reachable)

  chain_path = "/chain/#{URI.encode_www_form_component(ALLEGIANCE_SERVER)}/#{URI.encode_www_form_component(tree_fixture[:root_name])}"
  res = http_get(chain_path, headers: { "Accept" => "application/json" })
  check_status("GET #{chain_path}", res, 200)

  chain = JSON.parse(res.body) rescue nil
  chain_names = Set.new
  if chain.is_a?(Hash)
    queue = [chain]
    until queue.empty?
      node = queue.shift
      next unless node.is_a?(Hash) && node["name"]

      chain_names << node["name"]
      (node["children"] || []).each { |child| queue << child }
    end
  end

  rel_check.("chain response parsed as a tree", chain.is_a?(Hash))
  rel_check.("chain root matches generated root", chain.is_a?(Hash) && chain["name"] == tree_fixture[:root_name])
  rel_check.("chain traversal reaches all #{tree_names.length} names", chain_names == tree_name_set)

  puts ""
  puts "  Tree records validated: #{tree_names.length}"
  puts "  Relationship assertions: #{rel_pass} passed, #{rel_fail} failed"
  $pass += rel_pass
  $fail += rel_fail
end

puts ""

# ── summary ────────────────────────────────────────────────────────────────────

bold "=== Summary ==="
total = $pass + $fail
puts "  Total checks: #{$pass} passed, #{$fail} failed"
if $fail > 0
  red("  FAILED (#{$fail} failure#{"s" if $fail != 1})")
  exit 1
else
  green("  All checks passed.")
end
