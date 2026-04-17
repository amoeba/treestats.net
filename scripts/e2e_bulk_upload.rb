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
require "open3"

# Load app models + Mongoid so we can query MongoDB directly at the end.
require_relative "../app"

# ── configuration ──────────────────────────────────────────────────────────────

HOST     = ENV.fetch("HOST",     "localhost:3000")
ACCOUNT  = ENV.fetch("ACCOUNT",  "BulkE Two E")
PASSWORD = ENV.fetch("PASSWORD", "e2epassword")

BASE_URI = URI("http://#{HOST}")

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
def fail(label) = ($fail += 1; red("  \u2717 #{label}"))
def abort!(msg) = (red("FATAL: #{msg}"); exit(1))

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
    fail("#{label} → expected HTTP #{expected}, got HTTP #{got}  body=#{response.body.inspect}")
  end
end

def check_json(label, response, field, expected)
  body = JSON.parse(response.body) rescue {}
  got  = body[field.to_s]
  if got == expected
    pass("  #{label} ('#{field}' = #{got.inspect})")
  else
    fail("  #{label} — '#{field}': expected #{expected.inspect}, got #{got.inspect}")
  end
end

# ── signing ────────────────────────────────────────────────────────────────────

def sign(key, body)
  OpenSSL::HMAC.hexdigest("SHA256", key, body)
end

# ── rate-limit key flushing ────────────────────────────────────────────────────

def flush_rate_limit
  redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
  redis.del("bulk_upload:ratelimit:127.0.0.1")
end

# ── sidekiq management ─────────────────────────────────────────────────────────

$sidekiq_pid = nil

def start_sidekiq_if_needed
  running = system("pgrep -f 'sidekiq.*sidekiq_boot' > /dev/null 2>&1")
  if running
    pass("sidekiq already running")
    return
  end

  dim("  Starting sidekiq…")
  $sidekiq_pid = spawn(
    "bundle exec sidekiq -r ./lib/sidekiq_boot.rb",
    out: "/tmp/e2e_sidekiq.log", err: "/tmp/e2e_sidekiq.log"
  )
  sleep 2
  begin
    Process.kill(0, $sidekiq_pid)
    pass("sidekiq started (pid #{$sidekiq_pid})")
  rescue Errno::ESRCH
    abort!("sidekiq failed to start — see /tmp/e2e_sidekiq.log")
  end
end

at_exit do
  if $sidekiq_pid
    dim("  Stopping sidekiq (pid #{$sidekiq_pid})…")
    Process.kill("TERM", $sidekiq_pid) rescue nil
  end
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

bold "=== Bulk Upload End-to-End Tests ==="
puts "  host:    #{BASE_URI}"
puts "  account: #{ACCOUNT}"
puts ""

# ── 0. Infrastructure ──────────────────────────────────────────────────────────

bold "0. Infrastructure"
start_sidekiq_if_needed
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
  fail("API key format unexpected: '#{API_KEY[0, 20]}…' (len=#{API_KEY.length})")
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

fail("Rate limit never triggered after 20 requests") unless hit_429

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
  fail("Only #{found}/#{EXPECTED_NAMES.length} characters found after #{max_wait}s")
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

bold "9. Large allegiance upload (30,000 partial records)"

flush_rate_limit

ALLEGIANCE_SERVER = "Coldeve"
ALLEGIANCE_SIZE   = 30_000
RACES             = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]
GENDERS           = %w[1 2]
RANKS             = (1..10).to_a

allegiance_records = ALLEGIANCE_SIZE.times.map do |i|
  {
    "server" => ALLEGIANCE_SERVER,
    "name"   => "AllegMember#{i}",
    "race"   => RACES[i % RACES.length],
    "gender" => GENDERS[i % GENDERS.length],
    "rank"   => RANKS[i % RANKS.length],
  }
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
check_status("30,000-record allegiance NDJSON upload", res, 202)
check_json("body has status=queued", res, "status", "queued")

allegiance_log_id = (JSON.parse(res.body)["log_id"] rescue nil)
pass("Response includes log_id") if allegiance_log_id
fail("Response missing log_id")  unless allegiance_log_id

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

    if audit_log.record_count == ALLEGIANCE_SIZE
      pass("record_count matches submitted (#{ALLEGIANCE_SIZE})")
    else
      fail("record_count mismatch: expected #{ALLEGIANCE_SIZE}, got #{audit_log.record_count}")
    end

    if audit_log.processed_count == ALLEGIANCE_SIZE
      pass("all #{ALLEGIANCE_SIZE} records processed")
    else
      fail("processed_count=#{audit_log.processed_count} (expected #{ALLEGIANCE_SIZE})")
    end
  elsif audit_log&.status == "failed"
    fail("Job status=failed after #{waited}s")
  else
    fail("Job did not complete within #{max_wait}s (status=#{audit_log&.status || "not found"})")
  end
else
  yellow("  Skipping audit log check — no log_id from upload response")
end

puts ""

# ── 11. GET /admin/logs JSON ───────────────────────────────────────────────────

bold "11. GET /admin/logs (JSON)"

res = http_get("/admin/logs", headers: { "Accept" => "application/json" })
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
          ["record_count",    ALLEGIANCE_SIZE],
          ["processed_count", ALLEGIANCE_SIZE],
          ["skipped_count",   0],
          ["error_count",     0],
        ].each do |field, expected|
          actual = entry[field]
          if actual == expected
            pass("  #{field} = #{expected.inspect}")
          else
            fail("  #{field}: expected #{expected.inspect}, got #{actual.inspect}")
          end
        end

        pass("  duration_ms present") if entry["duration_ms"].is_a?(Integer)
        fail("  duration_ms missing or wrong type") unless entry["duration_ms"].is_a?(Integer)

        pass("  submitted_at present") if entry["submitted_at"]
        fail("  submitted_at missing")  unless entry["submitted_at"]
      else
        fail("Allegiance upload log not found in response (id=#{allegiance_log_id})")
      end
    else
      yellow("  Skipping per-entry checks — no allegiance_log_id available")
    end
  else
    fail("Response is not a JSON array: #{res.body[0, 200]}")
  end
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
